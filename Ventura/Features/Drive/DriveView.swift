import Combine
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct DriveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var permissionManager = PermissionManager.shared
    @EnvironmentObject private var sessionManager: SessionManager  // NEW: Injected
    @ObservedObject private var weatherManager = WeatherManager.shared

    // PERFORMANCE: Manual fetch instead of @Query to prevent
    // synchronous re-evaluation of ALL completed sessions on every foreground resume.
    // DriveView only needs the most recent session for display.
    @State private var lastSession: Session?
    
    private func loadLastSession() async {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endTimestamp != nil },
            sortBy: [SortDescriptor(\.endTimestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            lastSession = try modelContext.fetch(descriptor).first
        } catch {
            print("DriveView: Failed to fetch last session: \(error)")
        }
    }

    // Fetch user settings
    @Query private var settings: [UserSettings]

    @State private var showTipSheet = false
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .automatic
    )

    @State private var showEndAlert = false
    @State private var startStopTrigger = false



    @State private var isFollowingUser = true
    @State private var lastCenterTime: Date = .distantPast

    var activeSession: Session? {
        sessionManager.activeSession
    }


    var body: some View {
        ZStack {
            // MARK: - Map Layer (Static, no timer dependency)
            let userSettings = settings.first
            let homeCoord: CLLocationCoordinate2D? = {
                if let s = userSettings, let lat = s.homeLatitude, let lon = s.homeLongitude {
                   return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                return nil
            }()
            
            DriveSessionMap(
                position: $position,
                isFollowingUser: $isFollowingUser,
                session: activeSession,
                routeID: sessionManager.routeID,
                liveRoute: sessionManager.liveRoute,
                homeLocation: homeCoord,
                homeRadius: userSettings?.homeRadius ?? 0,
                homeName: userSettings?.homeName ?? "Home",
                homeIcon: userSettings?.homeIcon ?? "house.fill"
            )
            .equatable()
            .safeAreaPadding(.horizontal, 5)
            .safeAreaPadding(.bottom, 70)
            .safeAreaPadding(.top, 320)
            

            // MARK: - UI Overlay (Timer-dependent, extracted)
            DriveViewOverlay(
                activeSession: activeSession,
                lastSession: lastSession,
                settings: settings.first ?? UserSettings(),
                showTipSheet: $showTipSheet,
                showEndAlert: $showEndAlert,
                startStopTrigger: $startStopTrigger,
                position: $position,
                isFollowingUser: $isFollowingUser,
                lastCenterTime: $lastCenterTime,
                ticker: sessionManager.ticker,
                weatherUI: weatherManager.ui,
                weatherURL: weatherManager.weatherURL,
                onStart: startSession,
                onStop: stopSession
            )
            .padding(.top)
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.9),
            value: activeSession != nil
        )
        .sheet(isPresented: $showTipSheet) {
            LogDeliverySheet { amount, countAsDelivery in
                sessionManager.addTip(
                    amount,
                    countAsDelivery: countAsDelivery
                )
            }
        }


        .toolbar(.hidden, for: .navigationBar)
        .task {
            sessionManager.refreshSettings()
            await loadLastSession()
        }
    }

// MARK: - Drive View Overlay (Timer-dependent UI)
private struct DriveViewOverlay: View {
    let activeSession: Session?
    let lastSession: Session?
    let settings: UserSettings
    
    @Binding var showTipSheet: Bool
    @Binding var showEndAlert: Bool
    @Binding var startStopTrigger: Bool
    @Binding var position: MapCameraPosition
    @Binding var isFollowingUser: Bool
    @Binding var lastCenterTime: Date
    let ticker: SessionTicker
    let weatherUI: WeatherUIModel?
    let weatherURL: URL
    
    let onStart: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            LiveSessionStats(
                ticker: ticker,
                session: activeSession ?? lastSession,
                settings: settings,
                isLive: activeSession != nil,
                showHomeStats: settings.homeLatitude != nil
            )
            .onTapGesture {
                // Handle tap if needed
            }

                HStack {
                    if activeSession != nil {
                        Button {
                            showTipSheet = true
                        } label: {
                            Label(
                                "Delivery",
                                systemImage: "plus.circle.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .glassModifier(
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()

                    // Weather and Location Buttons
                    HStack {
                        Spacer()

                        // Weather Pill
                        if settings.showWeatherPill, let weather = weatherUI {
                            Link(destination: weatherURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: weather.conditionIcon)
                                        .symbolRenderingMode(.multicolor)
                                    Text(weather.temperature)
                                        .font(.headline)
                                        .lineLimit(1)
                                }
                                .padding(12)
                                .glassModifier(in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }



                        // Location Button
                        Button {
                            withAnimation {
                                lastCenterTime = Date()
                                position = .userLocation(
                                    fallback: .automatic
                                )
                                isFollowingUser = true
                            }
                        } label: {
                            Image(
                                systemName: isFollowingUser
                                    ? "location.fill" : "location"
                            )
                            .font(.title3)
                            .padding(12)
                            .glassModifier(in: Circle())
                        }
                    }
                }

                Spacer()

                // MARK: BOTTOM ACTION BUTTON
                if activeSession != nil {
                    // STOP BUTTON
                    Button {
                        showEndAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("End Session")
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.red)
                        .cornerRadius(20)
                        .glassModifier(
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                    }
                    .sensoryFeedback(.success, trigger: startStopTrigger)
                    .confirmationDialog(
                        "End Session?",
                        isPresented: $showEndAlert,
                        titleVisibility: .visible
                    ) {
                        Button("End Session", role: .destructive) {
                            startStopTrigger.toggle()
                            onStop()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "Are you sure you want to end your current session?"
                        )
                    }
                } else {
                    // START BUTTON
                    Button {
                        startStopTrigger.toggle()
                        onStart()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.green)
                        .cornerRadius(20)
                        .glassModifier(
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .sensoryFeedback(
                            .success,
                            trigger: startStopTrigger
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
    }
}

    private func startSession() {
        sessionManager.startSession()
    }

    private func stopSession() {
        sessionManager.stopSession()
        dismiss()
    }

    // --- HELPERS ---

    private func durationString(from date: Date, now: Date) -> String {
        let diff = max(0, now.timeIntervalSince(date))
        return TimeFormatter.formatDuration(diff)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        return TimeFormatter.formatDuration(seconds)
    }
}

// Helpers for Session formatting
extension Session {
    var startEndString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: startTimestamp)
    }
}


#Preview {
    let container = PreviewHelper.makeContainer()
    return NavigationStack {
        DriveView()
    }
    .modelContainer(container)
    .environmentObject(SessionManager())
}
