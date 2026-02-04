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
    @ObservedObject private var weatherManager = WeatherManager.shared  // For Temp Pill

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
    @State private var showGasPricesSheet = false
    @State private var isFollowingUser = true
    @State private var lastCenterTime: Date = .distantPast

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

                // Active Session Route
                if let session = activeSession, !session.route.isEmpty {
                    MapPolyline(
                        coordinates: session.route.map {
                            CLLocationCoordinate2D(
                                latitude: $0.latitude,
                                longitude: $0.longitude
                            )
                        }
                    )
                    .stroke(
                        .blue,
                        style: StrokeStyle(
                            lineWidth: 5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

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
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        isFollowingUser = false
                    }
            )
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
                    settings: settings.first ?? UserSettings(),
                    isLive: activeSession != nil,
                    timelineDate: timeline.date,
                    showHomeStats: settings.first?.homeLatitude != nil
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
                        if let weather = weatherManager.ui {
                            Link(destination: weatherManager.weatherURL) {
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

                        // Gas Button
                        Button {
                            showGasPricesSheet = true
                        } label: {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                                .padding(12)
                                .glassModifier(in: Circle())
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
                sessionManager.addTip(
                    amount,
                    countAsDelivery: countAsDelivery
                )
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            // When sheet is dismissed after ending a session, return to dashboard
            dismiss()
        } content: {
            if let sessionToShow = sessionManager.lastEndedSession
                ?? lastSession
            {
                NavigationStack {
                    SessionSummarySheet(
                        session: sessionToShow,
                        isPresentedAsSheet: true
                    )
                }
                #if os(iOS)
                    .presentationDetents([.fraction(0.95)])
                    .presentationDragIndicator(.visible)
                #endif
            }
        }
        .sheet(isPresented: $showGasPricesSheet) {
            GasPricesSheet()
                #if os(iOS)
                    .presentationDetents([.fraction(0.58), .fraction(0.95)])
                    .presentationDragIndicator(.visible)
                #endif
        }
        .navigationTitle("Drive")
        .navigationBarTitleDisplayMode(.inline)
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
