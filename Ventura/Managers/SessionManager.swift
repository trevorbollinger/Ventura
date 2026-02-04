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
    
    // Timer
    private var timer: AnyCancellable?
    private var locationSubscription: AnyCancellable?
    
    // Fallback for timer loop
    private var lastUpdateDate: Date = Date()
    
    init() {}
    
    /// Called once at app startup (e.g. from VenturaTabs.onAppear) to inject the context
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🔧 SessionManager configured with context")
        
        // Load any existing active session
        checkForActiveSession()
        
        // Start monitoring loop if active
        if activeSession != nil {
            startTimer()
            startLocationMonitoring()
            // Restore tracker distance
            locationTracker.setDistance(activeSession?.gpsDistanceMeters ?? 0)
            locationTracker.startTracking()
            
            // Fetch current settings for Live Activity
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let userSettings = (try? modelContext.fetch(settingsDescriptor).first) ?? UserSettings()
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
        
        startTimer()
        startLocationMonitoring()
        
        LiveActivityManager.shared.start(session: newSession, settings: userSettings)
        print("✅ Session Started")
    }
    
    func stopSession() {
        guard let session = activeSession else { return }
        
        // Final sync
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
        }
        print("🛑 Session Stopped")
    }
    
    func addTip(_ amount: Decimal, countAsDelivery: Bool) {
        guard let session = activeSession else { return }
        session.tips.append(amount)
        if countAsDelivery {
            session.deliveriesCount += 1
        }
        session.invalidateCache()
        
        // Fetch current settings for Live Activity update
        guard let context = modelContext else { return }
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let userSettings = (try? context.fetch(settingsDescriptor).first) ?? UserSettings()
        LiveActivityManager.shared.update(session: session, settings: userSettings)
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
        guard let session = activeSession, let context = modelContext else { return }
        
        let now = Date()
        // Calculate exact wall-clock time passed to avoid drift
        let totalDuration = now.timeIntervalSince(session.startTimestamp)
        let currentRecorded = session.timeAtHome + session.timeAway
        let timePassed = max(0, totalDuration - currentRecorded)
        
        lastUpdateDate = now
        session.gpsDistanceMeters = locationTracker.totalDistance
        
        // --- Wage Calculation Logic ---
        
        // Fetch Settings for Geofence
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let userSettings = (try? context.fetch(settingsDescriptor).first) ?? UserSettings()
        
        // Extensive Debugging

        
        // --- 1. Update Time Buckets (Stats Only) ---
        // Refined Logic (User Request):
        // Strict check: Only count as "Home Time" if we are definitively INSIDE the home circle.
        // Otherwise (Outside, No Home Set, No GPS), count as "Time Away" (Driving/Active).
        
        var isIndeedAtHome = false
        
        if let lat = userSettings.homeLatitude,
           let lon = userSettings.homeLongitude,
           let currentLocation = locationTracker.currentLocation {
            
            let homeLocation = CLLocation(latitude: lat, longitude: lon)
            let distanceToHome = currentLocation.distance(from: homeLocation)
            
            if distanceToHome <= userSettings.homeRadius {
                isIndeedAtHome = true
            }
        }
        
        if isIndeedAtHome {
            session.timeAtHome += timePassed
        } else {
            session.timeAway += timePassed
        }

        // Debugging
        let debugSpeed = locationTracker.currentLocation?.speed ?? 0
        let debugMoving = locationTracker.isEffectivelyMoving
        let debugEarnings = session.grossEarnings
        let debugHourly = session.earningsPerHour
        
        print("📍 [GPS] Spd: \(String(format: "%.1f", debugSpeed))m/s | Mov: \(debugMoving) | Dist: \(Int(session.gpsDistanceMeters))m | 💰 Pay: \(debugEarnings.formatted(.currency(code: "USD"))) | Rate: \(debugHourly.formatted(.currency(code: "USD")))/hr")
        
        // Periodically save
        if Int(session.timeAway + session.timeAtHome) % 5 == 0 {
            try? context.save()
        }
        
        LiveActivityManager.shared.update(session: session, settings: userSettings)
    }
    
    private func processLocationUpdate(_ location: CLLocation?) {
        guard let location = location, let session = activeSession else { return }
        
        // Route Smoothing: Only record if moving or first point
        if locationTracker.isEffectivelyMoving || session.route.isEmpty {
            let locationData = LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                speed: location.speed,
                altitude: location.altitude
            )
            session.route.append(locationData)
            
            // Fetch current settings for Live Activity
            if let ctx = modelContext {
                let settingsDescriptor = FetchDescriptor<UserSettings>()
                let userSettings = (try? ctx.fetch(settingsDescriptor).first) ?? UserSettings()
                LiveActivityManager.shared.update(session: session, settings: userSettings)
            }
        }
    }
    
    private func syncSessionData() {
        guard let session = activeSession else { return }
        session.gpsDistanceMeters = locationTracker.totalDistance
    }
}
