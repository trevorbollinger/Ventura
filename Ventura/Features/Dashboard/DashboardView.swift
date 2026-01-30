import Combine
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var locationTracker = LocationTracker.shared

    // Active session (one that hasn't ended)
    @Query(filter: #Predicate<Session> { $0.endTimestamp == nil })
    private var activeSessions: [Session]

    // Completed sessions for summary
    @Query(
        filter: #Predicate<Session> { $0.endTimestamp != nil },
        sort: \Session.endTimestamp,
        order: .reverse
    )
    private var completedSessions: [Session]

    // Fetch user settings
    @Query private var settings: [UserSettings]

    // Timer sync GPS distance
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showTipSheet = false
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .automatic
    )

    // Alert states
    @State private var showEndAlert = false
    @State private var startStopTrigger = false

    // Summary sheet state
    @State private var showSummarySheet = false
    @State private var lastEndedSession: Session?
    @State private var lastUpdateDate: Date = Date()

    var activeSession: Session? {
        activeSessions.first
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
            .mapControls {
//                MapCompass()
//                MapScaleView()
            }
            .safeAreaPadding(.horizontal, 10)
            .safeAreaPadding(.bottom, 70)
            .safeAreaPadding(.top, 288)
            
            // MARK: - TOP CARD
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                VStack(spacing: 10) {

                    // --- TOP CARD SECTION ---
                    // --- TOP CARD SECTION ---
                    VStack(spacing: 24) {
                        // Determine what to show: Active Session -> Last Session -> Empty State
                        let session = activeSession ?? lastSession
                        let isLive = activeSession != nil
                        let isEmpty = session == nil

                        // 1. Header Section
                        HStack {
                            HStack(spacing: 8) {
                                if isLive {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: .green.opacity(0.5), radius: 4)
                                    Text("Tracking Session")
                                        .foregroundStyle(.green)
                                } else if isEmpty {
                                    Image(systemName: "car.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text("Ready to Drive")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                    Text("Last Session")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.bold))

                            Spacer()

                            if let s = session, !isLive {
                                Text(s.startEndString)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary.opacity(0.8))
                            } else {
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                        }

                        // 2. Earnings Hero (Dopamine center)
                        VStack(spacing: 8) {
                            Text(session?.netProfit.formatted(.currency(code: "USD")) ?? "$0.00")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .contentTransition(.numericText())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)

                            HStack(spacing: 12) {
                                Text("NET PROFIT")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .foregroundStyle(.orange)
                                    Text(session?.earningsPerHour.formatted(.currency(code: "USD")) ?? "$0.00")
                                        .contentTransition(.numericText())
                                        .foregroundStyle(.primary)
                                    Text("/ hr")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption.bold())
                            }
                        }
                        
                        // 3. Stats Grid with Pop
                        VStack(spacing: 16) {
                            // Row 1
                            HStack {
                                // Duration
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 32, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("TIME")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(isLive ? durationString(from: session?.startTimestamp ?? Date(), now: timeline.date) : (session?.durationString ?? "0h 0m"))
                                            .font(.headline)
                                            .contentTransition(.numericText())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Miles
                                HStack(spacing: 12) {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("MILES")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(session != nil ? String(format: "%.1f", session!.totalMiles) : "0.0")
                                            .font(.headline)
                                            .contentTransition(.numericText())
                                    }
                                    
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .foregroundStyle(.indigo)
                                        .frame(width: 32, alignment: .center)

                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                            // Row 2
                            HStack {
                                // Home
                                HStack(spacing: 12) {
                                    Image(systemName: "house.fill")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                        .frame(width: 32, alignment: .center)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("HOME")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(formatSeconds(session?.timeAtHome ?? 0))
                                            .font(.headline)
                                            .contentTransition(.numericText())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Away
                                HStack(spacing: 12) {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("AWAY")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(formatSeconds(session?.timeAway ?? 0))
                                            .font(.headline)
                                            .contentTransition(.numericText())
                                    }
                                    
                                    Image(systemName: "car.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                        .frame(width: 32, alignment: .center)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .glassModifier(in: RoundedRectangle(cornerRadius: 24))
                    .shadow(color: activeSession != nil ? .green.opacity(0.1) : .clear, radius: 20, x: 0, y: 10)

                  
                    
                    HStack {
                        
                        if activeSession != nil {
                            
                            Button {
                                showTipSheet = true
                            } label: {
                                Label(
                                    "Add Tip",
                                    systemImage: "dollarsign.circle.fill"
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
                        .sensoryFeedback(
                            .impact(weight: .medium, intensity: 1.0),
                            trigger: startStopTrigger
                        )
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

            // --- LOGIC / EVENTS ---
            .onReceive(timer) { _ in
                // Sync GPS distance to active session
                if let session = activeSession {
                    let now = Date()
                    // Force the accumulated time (Ticks) to match the wall-clock duration exactly.
                    // This eliminates the tiny drift (e.g. 0.03s) at startup that causes Rate < Wage.
                    let totalDuration = now.timeIntervalSince(session.startTimestamp)
                    let currentRecorded = session.timeAtHome + session.timeAway
                    var timePassed = max(0, totalDuration - currentRecorded)
                    
                    // Update fallback reference
                    lastUpdateDate = now

                    session.gpsDistanceMeters = locationTracker.totalDistance

                    // --- Time & Pay Tracking ---
                    // Increment correct counter by actual time passed and accumulate pay
                    if let userSettings = settings.first,
                        let lat = userSettings.homeLatitude,
                        let lon = userSettings.homeLongitude,
                        let currentLocation = locationTracker.currentLocation
                    {
                        let homeLocation = CLLocation(
                            latitude: lat,
                            longitude: lon
                        )
                        let distanceToHome = currentLocation.distance(
                            from: homeLocation
                        )

                        if distanceToHome <= userSettings.homeRadius {
                            session.timeAtHome += timePassed

                            if session.wageTypeRaw == "Split" {
                                // Passive Rate
                                let earnings = (Decimal(session.passiveWage) / 3600) * Decimal(timePassed)
                                session.homePay += earnings
                            }
                        } else {
                            session.timeAway += timePassed

                            if session.wageTypeRaw == "Split" {
                                // Active Rate (Driving Wage)
                                let earnings = (Decimal(session.drivingWage) / 3600) * Decimal(timePassed)
                                session.drivingPay += earnings
                            }
                        }
                    } else {
                        // Default to Away if no home set or GPS not yet found
                        session.timeAway += timePassed

                        if session.wageTypeRaw == "Split" {
                            // Active Rate (Driving Wage)
                            let earnings = (Decimal(session.drivingWage) / 3600) * Decimal(timePassed)
                            session.drivingPay += earnings
                        }
                    }

                    // Periodically save to ensure UI updates and persistence
                    if Int(session.timeAway + session.timeAtHome) % 5 == 0 {
                        try? modelContext.save()
                    }

                    LiveActivityManager.shared.update(session: session)
                }
            }
            .onReceive(locationTracker.$currentLocation) { location in
                guard let location = location, let session = activeSession
                else { return }

                let locationData = LocationData(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp,
                    speed: location.speed,
                    altitude: location.altitude
                )
                session.route.append(locationData)
                LiveActivityManager.shared.update(session: session)
            }
            // ...
            .onAppear {
                // Resume tracking if there's an active session on app launch
                if let session = activeSession {
                    locationTracker.startTracking()
                    lastUpdateDate = Date() // Reset timer logic to avoid huge jump on resume
                    LiveActivityManager.shared.start(session: session)
                }
            }
            .sheet(isPresented: $showTipSheet) {
                TipEntrySheet { amount in
                    if let session = activeSession {
                        session.tips.append(amount)
                        session.invalidateCache()  // Force recalculation
                        LiveActivityManager.shared.update(session: session)
                    }
                }
            }

            .sheet(isPresented: $showSummarySheet) {
                if let lastSession = lastEndedSession {
                    NavigationStack {
                        SessionSummarySheet(session: lastSession)
                    }
                    #if os(iOS)
                        .presentationDetents([.fraction(0.95)])
                        .presentationDragIndicator(.visible)
                    #endif
                }
            }
            .onAppear {
                // Resume tracking if there's an active session on app launch
                if let session = activeSession {
                    locationTracker.startTracking()
                    LiveActivityManager.shared.start(session: session)
                }
            }
        }
    }

    private func startSession() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            let userSettings = settings.first ?? UserSettings()  // Use default if none found
            let newSession = Session(userSettings: userSettings)
            modelContext.insert(newSession)

            // Start GPS tracking
            locationTracker.resetDistance()
            locationTracker.startTracking()

            // Start Live Activity
            LiveActivityManager.shared.start(session: newSession)
        }
    }

    private func stopSession() {
        if let session = activeSession {
            // Final sync of GPS distance before closing
            session.gpsDistanceMeters = locationTracker.totalDistance
            session.endTimestamp = Date()
            session.manualEndOdometer = session.gpsDistanceMeters / 1609.34  // Initialize odometer with GPS miles

            // Capture for summary sheet
            lastEndedSession = session

            // Stop GPS tracking
            locationTracker.stopTracking()

            // End Live Activity
            LiveActivityManager.shared.end()

            try? modelContext.save()

            // Show summary sheet
            showSummarySheet = true
        }
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

    var durationString: String {
        guard let end = endTimestamp else { return "Active" }
        let diff = end.timeIntervalSince(startTimestamp)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    return VenturaTabs()
        .modelContainer(container)
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    return VenturaTabs()
        .modelContainer(container)
}
