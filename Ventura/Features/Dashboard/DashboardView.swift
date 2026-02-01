import Combine
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var permissionManager = PermissionManager.shared
    @EnvironmentObject private var sessionManager: SessionManager // NEW: Injected

    // Removed local active/completed queries - use SessionManager or local summary query
    // Keep completed sessions for summary
    @Query(
        filter: #Predicate<Session> { $0.endTimestamp != nil },
        sort: \Session.endTimestamp,
        order: .reverse
    )
    private var completedSessions: [Session]

    // Fetch user settings
    @Query private var settings: [UserSettings]

    @State private var showTipSheet = false
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .automatic
    )

    @State private var showEndAlert = false
    @State private var startStopTrigger = false

    @State private var showSummarySheet = false

    var activeSession: Session? {
        sessionManager.activeSession
    }

    var lastSession: Session? {
        completedSessions.first
    }

    var body: some View {
        ZStack {
            // MARK: - Map Layer
            Map(position: $position) {
                UserAnnotation()

                if let userSettings = settings.first,
                    let lat = userSettings.homeLatitude,
                    let lon = userSettings.homeLongitude
                {
                    let homeCoord = CLLocationCoordinate2D(
                        latitude: lat,
                        longitude: lon
                    )

                    MapCircle(
                        center: homeCoord,
                        radius: userSettings.homeRadius
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue.opacity(0.3), lineWidth: 2)

                    Marker(
                        userSettings.homeName ?? "Home",
                        systemImage: userSettings.homeIcon ?? "house.fill",
                        coordinate: homeCoord
                    )
                    .tint(.blue)
                }
            }
            .mapStyle(
                .standard(
                    elevation: .realistic,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: true
                )
            )
            .safeAreaPadding(.horizontal, 5)
            .safeAreaPadding(.bottom, 70)
            .safeAreaPadding(.top, 320)
            
            // MARK: - TOP CARD
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                VStack(spacing: 10) {

        
                    SessionStatsCard(
                        session: activeSession ?? lastSession,
                        isLive: activeSession != nil,
                        timelineDate: timeline.date
                    )
                    .onTapGesture {
                        if activeSession == nil {
                            showSummarySheet = true
                        }
                    }

                    
                    HStack {
                        
                        if activeSession != nil {
                            
                            Button {
                                showTipSheet = true
                            } label: {
                                Label(
                                    "Log Delivery",
                                    systemImage: "text.pad.header.badge.plus"
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
                        // Location Button
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    position = .userLocation(
                                        fallback: .automatic
                                    )
                                }
                            } label: {
                                Image(systemName: "location.fill")
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
                                stopSession()
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
                            startSession()
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
            .animation(
                .spring(response: 0.3, dampingFraction: 0.9),
                value: activeSession != nil
            )
            // MARK: Logic Handlers (Moved to SessionManager)
            .sheet(isPresented: $showTipSheet) {
                LogDeliverySheet { amount, countAsDelivery in
                    sessionManager.addTip(amount, countAsDelivery: countAsDelivery)
                }
            }
            .sheet(isPresented: $showSummarySheet) {
                if let sessionToShow = sessionManager.lastEndedSession ?? lastSession {
                    NavigationStack {
                        SessionSummarySheet(session: sessionToShow, isPresentedAsSheet: true)
                    }
                    #if os(iOS)
                        .presentationDetents([.fraction(0.95)])
                        .presentationDragIndicator(.visible)
                    #endif
                }
            }
        }
    }

    private func startSession() {
        sessionManager.startSession()
    }

    private func stopSession() {
        sessionManager.stopSession()
        showSummarySheet = true
    }

    // --- HELPERS ---

    private func durationString(from date: Date, now: Date) -> String {
        let diff = max(0, now.timeIntervalSince(date))
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60

        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
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
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
}
