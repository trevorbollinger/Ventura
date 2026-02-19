//
//  SessionManager.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/31/26.
//

import Foundation
import SwiftData
import CoreLocation
import Combine
import SwiftUI

/// Manages the active session, timer, wage calculations, and GPS synchronization.
/// Designed to persist and run independently of the Dashboard UI.
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager() // Shared for convenience, but we'll try to use Environment
    
    // Dependencies
    private var modelContext: ModelContext?
    @ObservedObject var locationTracker = LocationTracker.shared
    
    // State
    @Published var activeSession: Session?
    @Published var lastEndedSession: Session?
    
    // Dependencies
    public let ticker = SessionTicker()
    

    
    // Timer
    private var timer: AnyCancellable?
    private var locationSubscription: AnyCancellable?
    
    // Fallback for timer loop
    private var lastUpdateDate: Date = Date()
    
    // Performance Cache — exposed so views can read settings without their own @Query
    @Published var cachedSettings: UserSettings?
    
    // Aggregation State (prevents 1Hz DB writes)
    private var pendingTimeAtHome: TimeInterval = 0
    private var pendingTimeAway: TimeInterval = 0
    private var pendingDistance: Double = 0 // In meters
    @Published private(set) var pendingRoutePoints: [LocationData] = [] // Buffered GPS points (exposed for live map)
    private var lastRouteIDUpdate: Date = .distantPast // Throttle routeID
    
    /// The full live route: saved points + in-memory pending points.
    /// Maps should use this instead of session.route to see the trail immediately.
    var liveRoute: [LocationData] {
        (activeSession?.route ?? []) + pendingRoutePoints
    }
    
    // Live UI State (Published for views)
    struct ActiveSessionState {
        var totalDuration: TimeInterval = 0
        var timeAtHome: TimeInterval = 0
        var timeAway: TimeInterval = 0
        var distanceMeters: Double = 0
        var isSessionActive: Bool = false
    }
    
    // REMOVED @Published sessionState to prevent main thread thrashing
    
    // UI Optimization Signals
    @Published var routeID: UUID = UUID() // Updates only when location/route changes
    
    init() {}
    
    /// Called once at app startup to inject the context. Instant — no disk I/O.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🔧 SessionManager configured with context")
    }
    
    /// Performs the initial SwiftData fetches. Call from `.task` so the run loop
    /// can yield between operations and the first frame isn't blocked.
    func loadInitialData() async {
        guard let context = modelContext else { return }
        
        // 1. Load settings (async-friendly: yields back to run loop after this)
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let userSettings = (try? context.fetch(settingsDescriptor).first) ?? UserSettings()
        self.cachedSettings = userSettings
        
        // Yield so the UI can draw its first frame with defaults if needed
        await Task.yield()
        
        // 2. Check for an active session
        checkForActiveSession()
        
        // 3. Resume monitoring if a session was already in progress
        if activeSession != nil {
            startTimer()
            startLocationMonitoring()
            locationTracker.setDistance(activeSession?.gpsDistanceMeters ?? 0)
            locationTracker.startTracking()
            
            LiveActivityManager.shared.start(session: activeSession!, settings: userSettings)
        }
    }
    
    private func checkForActiveSession() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endTimestamp == nil }
        )
        
        do {
            let sessions = try context.fetch(descriptor)
            self.activeSession = sessions.first
            if let s = activeSession {
                print("🔄 Resuming active session: \(s.id)")

            }
        } catch {
            print("❌ Failed to fetch active session: \(error)")
        }
    }
    
    // MARK: - Actions
    
    func startSession() {
        guard let context = modelContext else { return }
        
        // Fetch UserSettings
        var userSettings = UserSettings()
        let descriptor = FetchDescriptor<UserSettings>()
        if let fetched = try? context.fetch(descriptor).first {
            userSettings = fetched
            self.cachedSettings = fetched // Cache it
        }
        
        let newSession = Session(userSettings: userSettings)
        context.insert(newSession)
        
        withAnimation {
            self.activeSession = newSession
        }
        
        // Start sub-systems

        locationTracker.resetDistance()
        locationTracker.startTracking()
        lastUpdateDate = Date()
        self.routeID = UUID() // Reset for new session
        
        // Reset aggregation
        pendingTimeAtHome = 0
        pendingTimeAway = 0
        pendingDistance = 0
        pendingRoutePoints = []
        lastRouteIDUpdate = .distantPast
        
        startTimer()
        startLocationMonitoring()
        
        let currentState = currentSessionState(session: newSession, settings: userSettings)
        LiveActivityManager.shared.start(session: newSession, settings: userSettings)
        // Ensure initial state is pushed
        LiveActivityManager.shared.update(state: currentState, force: true)
        print("✅ Session Started")
    }
    
    /// Manually refreshes cached settings from the database
    func refreshSettings() {
        guard let context = modelContext else { return }
        if let first = try? context.fetch(FetchDescriptor<UserSettings>()).first {
             self.cachedSettings = first
             print("⚙️ SessionManager refreshed settings")
        }
    }
    
    func stopSession() {
        guard let session = activeSession else { return }
        
        // Final sync
        flushPendingData()
        syncSessionData()
        
        session.endTimestamp = Date()
        session.manualEndOdometer = session.gpsDistanceMeters / 1609.34
        
        lastEndedSession = session
        
        // Stop sub-systems
        locationTracker.stopTracking()
        stopTimer()
        locationSubscription?.cancel()
        
        LiveActivityManager.shared.end()
        
        try? modelContext?.save()
        
        withAnimation {
            self.activeSession = nil
            self.ticker.state = ActiveSessionState() // Reset Ticker
        }
        print("🛑 Session Stopped")
    }
    
    func addTip(_ amount: Decimal, countAsDelivery: Bool) {
        guard let session = activeSession else { return }
        
        // Flush before modifying to keep state consistent
        flushPendingData()
        
        session.tips.append(amount)
        if countAsDelivery {
            session.deliveriesCount += 1
        }
        session.invalidateCache()
        
        // Fetch current settings for Live Activity update
        var userSettings = self.cachedSettings ?? UserSettings()
        if self.cachedSettings == nil, let context = modelContext {
             userSettings = (try? context.fetch(FetchDescriptor<UserSettings>()).first) ?? UserSettings()
             self.cachedSettings = userSettings
        }
        
        let currentState = currentSessionState(session: session, settings: userSettings)
        LiveActivityManager.shared.update(state: currentState, force: true)
    }
    
    // MARK: - Logic Loop
    
    private func startTimer() {
        timer?.cancel()
        lastUpdateDate = Date()
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processTimerTick()
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func startLocationMonitoring() {
        locationSubscription?.cancel()
        locationSubscription = locationTracker.$currentLocation
            .sink { [weak self] location in
                self?.processLocationUpdate(location)
            }
    }
    
    /// The core logic loop - runs every second
    private func processTimerTick() {
        guard let session = activeSession else { return }
        
        // print("⏱️ Tick Start")

        
        let now = Date()
        let totalDuration = now.timeIntervalSince(session.startTimestamp)
        
        // Calculate total recorded time (Saved + Pending)
        let currentRecorded = session.timeAtHome + session.timeAway + pendingTimeAtHome + pendingTimeAway
        let timePassed = max(0, totalDuration - currentRecorded)
        
        lastUpdateDate = now
        
        // Update Pending Distance
        let totalTrackerDistance = locationTracker.totalDistance
        let savedDistance = session.gpsDistanceMeters
        pendingDistance = max(0, totalTrackerDistance - savedDistance)
        
        // --- Lightweight Home/Away Logic ---
        // Accessing UserSettings is risky if fetched, but we use cachedSettings (memory)
        var isIndeedAtHome = false
        if let settings = cachedSettings,
           let lat = settings.homeLatitude,
           let lon = settings.homeLongitude,
           let currentLocation = locationTracker.currentLocation {
            
            let homeLocation = CLLocation(latitude: lat, longitude: lon)
            if currentLocation.distance(from: homeLocation) <= settings.homeRadius {
                isIndeedAtHome = true
            }
        }
        
        // Update PENDING values (In-Memory Only)
        if isIndeedAtHome {
            pendingTimeAtHome += timePassed
        } else {
            pendingTimeAway += timePassed
        }

        let totalPendingTime = pendingTimeAtHome + pendingTimeAway
        
        // Periodically save (Flush every 60s) for persistence safety
        if totalPendingTime >= 60 {
            print("💾 Flushing 60s of data to DB...")
            flushPendingData()
            try? modelContext?.save()
        }
        
        // Update UI State (Lightweight - via Ticker)
        // enforce consistency by summing components
        let liveTimeAtHome = session.timeAtHome + pendingTimeAtHome
        let liveTimeAway = session.timeAway + pendingTimeAway
        let liveTotalDuration = liveTimeAtHome + liveTimeAway
        
        ticker.state = ActiveSessionState(
            totalDuration: liveTotalDuration,
            timeAtHome: liveTimeAtHome,
            timeAway: liveTimeAway,
            distanceMeters: session.gpsDistanceMeters + pendingDistance,
            isSessionActive: true
        )
        
        // Update Live Activity (Throttled: Every 15s or if distance changed significantly)
        // For simplicity, just every 15s for now to ensure smoothness.
        // We use Int(totalDuration) % 15 == 0 check.
        if Int(totalDuration) % 15 == 0 {
             let currentState = currentSessionState(session: session, settings: cachedSettings ?? UserSettings())
             LiveActivityManager.shared.update(state: currentState)
        }
    }
    
    private func processLocationUpdate(_ location: CLLocation?) {
        guard let location = location, let session = activeSession else { return }
        
        // Route Smoothing: Only record if moving or first point
        if locationTracker.diagnostics.isEffectivelyMoving || session.route.isEmpty {
            let locationData = LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                speed: location.speed,
                altitude: location.altitude
            )
            // Buffer route point in memory (flushed to DB with flushPendingData)
            pendingRoutePoints.append(locationData)
            
            // Throttle routeID signal to every 2 seconds for smooth map updates
            // without 1Hz redraws
            let now = Date()
            if now.timeIntervalSince(lastRouteIDUpdate) >= 2 {
                self.routeID = UUID()
                lastRouteIDUpdate = now
            }
        }
    }
    
    private func syncSessionData() {
        guard let session = activeSession else { return }
        session.gpsDistanceMeters = locationTracker.totalDistance
    }
    
    private func flushPendingData() {
        guard let session = activeSession else { return }
        
        if pendingTimeAtHome > 0 || pendingTimeAway > 0 || pendingDistance > 0 {
            session.timeAtHome += pendingTimeAtHome
            session.timeAway += pendingTimeAway
            // Safe to trust totalDistance here as the source of truth
            session.gpsDistanceMeters = locationTracker.totalDistance
            
            pendingTimeAtHome = 0
            pendingTimeAway = 0
            pendingDistance = 0
        }
        
        // Flush buffered route points to SwiftData
        if !pendingRoutePoints.isEmpty {
            session.route.append(contentsOf: pendingRoutePoints)
            pendingRoutePoints = []
            // Also update routeID so map picks up new points
            self.routeID = UUID()
            lastRouteIDUpdate = Date()
        }
    }
    
    // Helper to construct "Live" state from Session + Pending Data
    public func currentSessionState(session: Session, settings: UserSettings) -> SessionActivityAttributes.ContentState {
        // Calculate virtual totals
        let liveTotalMiles = (session.gpsDistanceMeters + pendingDistance) / 1609.34
        
        // 1. Calculate Gross Earnings
        let tipsTotal = session.tips.reduce(0, +)
        
        // Time Buckets
        let liveTimeAway = session.timeAway + pendingTimeAway
        let liveTimeAtHome = session.timeAtHome + pendingTimeAtHome
        let liveTotalTime = liveTimeAway + liveTimeAtHome
        
        // Wage Calculation (Must match Session.swift logic)
        let wage: Decimal
        if settings.wageType == .hourly {
             // Standard Hourly: Pay for ALL time (Home + Away)
             let totalHours = Decimal(liveTotalTime) / 3600.0
             wage = Decimal(settings.hourlyWage) * totalHours
        } else if settings.wageType == .split {
            // Split: Pay differently for Home vs Away
            let awayHours = Decimal(liveTimeAway) / 3600.0
            let homeHours = Decimal(liveTimeAtHome) / 3600.0
            wage = (Decimal(settings.drivingWage) * awayHours) + (Decimal(settings.passiveWage) * homeHours)
        } else {
             wage = 0
        }
        
        // Reimbursement Calculation (Missing Piece!)
        let mileagePay: Decimal
        if settings.reimbursementType == .perMile {
            mileagePay = Decimal(settings.reimbursement) * Decimal(liveTotalMiles)
        } else {
            mileagePay = 0
        }
        
        let deliveryPay: Decimal
        if settings.reimbursementType == .perDelivery {
            deliveryPay = Decimal(settings.reimbursement) * Decimal(session.deliveriesCount)
        } else {
            deliveryPay = 0
        }
        
        let grossMsg = tipsTotal + wage + mileagePay + deliveryPay
        
        // 2. Expenses
        let totalMilesDecimal = Decimal(liveTotalMiles)
        
        let fuelExpense: Decimal
        if settings.includeGas && settings.mpg > 0 {
             let gallons = totalMilesDecimal / Decimal(settings.mpg)
             fuelExpense = gallons * Decimal(settings.fuelPrice)
        } else {
            fuelExpense = 0
        }
        
        let maintenanceExpense: Decimal
        if settings.includeMaintenance {
            maintenanceExpense = totalMilesDecimal * Decimal(settings.maintenanceCostPerMile)
        } else {
            maintenanceExpense = 0
        }
        
        let totalExpenses = fuelExpense + maintenanceExpense
        
        // 3. Net Profit
        let netProfit = grossMsg - totalExpenses
        
        // 4. Hourly Rate Calculation
        let hoursTotal = liveTotalTime / 3600.0
        // Use a minimum of 1 minute to prevent huge spikes at 00:01
        // Use a minimum of 1 minute to prevent huge spikes at 00:01
        // let safeHours = max(hoursTotal, 1.0/60.0) // Unused

        let netHourly: Decimal = hoursTotal > 0 ? netProfit / Decimal(hoursTotal) : 0
        
        // 5. Per Distance
        let netPerDist: Double = liveTotalMiles > 0 ? NSDecimalNumber(decimal: netProfit / totalMilesDecimal).doubleValue : 0
        
        // Display conversions
        let displayDistance = settings.displayDistance(miles: liveTotalMiles)
        let displayPerDistance = settings.displayPerDistance(perMile: netPerDist)
        
        return SessionActivityAttributes.ContentState(
            totalEarnings: NSDecimalNumber(decimal: grossMsg).doubleValue,
            netProfit: NSDecimalNumber(decimal: netProfit).doubleValue,
            netHourlyProfit: NSDecimalNumber(decimal: netHourly).doubleValue,
            netPerDistance: displayPerDistance,
            deliveryCount: session.deliveriesCount,
            totalDistance: displayDistance,
            lastUpdated: Date(),
            currencyCode: settings.currencyCode,
            distanceUnitRaw: settings.distanceUnitRaw
        )
    }
}
