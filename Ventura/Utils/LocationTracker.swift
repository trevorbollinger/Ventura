//
//  LocationTracker.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import Foundation
import CoreLocation
import Combine

class LocationTracker: NSObject, ObservableObject {
    static let shared = LocationTracker()
    
    private let locationManager = CLLocationManager()
    private var isTracking = false
    
    // --- Tracking State ---
    @Published var totalDistance: Double = 0.0 // in meters
    @Published var currentLocation: CLLocation?
    
    // --- Debug / Diagnostics ---
    @Published var trackingStatus: String = "Idle"
    @Published var gpsAccuracy: Double = 0.0
    @Published var currentSpeedMph: Double = 0.0
    @Published var dataPointsCollected: Int = 0
    @Published var isEffectivelyMoving: Bool = false
    
    private var lastValidLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .automotiveNavigation
        
        // Critical for mileage tracking: prevent OS from killing location services when stopped
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Enable background updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        
        // Default to a reasonable accuracy, but startTracking() will enforce the best
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        // Do NOT reset totalDistance here, as we may be restoring an existing session.
        // resetDistance() should be called explicitly for new sessions.
        
        // Enforce maximum accuracy for tracking session
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10 // Capture updates every 10 meters - Sweet spot for accuracy vs data size
        locationManager.startUpdatingLocation()
        
        trackingStatus = "Active (High Precision)"
        print("📍 Started high-precision tracking")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        locationManager.stopUpdatingLocation()
        lastValidLocation = nil
        trackingStatus = "Stopped"
        print("📍 Stopped tracking")
    }
    
    func resetDistance() {
        totalDistance = 0.0
        dataPointsCollected = 0
        lastValidLocation = nil
        isEffectivelyMoving = false
        trackingStatus = "Distance Reset"
    }
    
    func setDistance(_ meters: Double) {
        totalDistance = meters
        print("📍 Restored distance to: \(meters) meters")
    }
    
    private func isValidLocation(_ location: CLLocation) -> Bool {
        // Filter out invalid locations
        guard location.horizontalAccuracy >= 0 else {
            return false
        }
        
        // Filter out very poor accuracy (e.g. > 50 meters)
        // This prevents massive distance jumps in poor signal areas
        if location.horizontalAccuracy > 50 {
            return false
        }
        
        // Filter unrealistic speeds (> 200 mph = 89.4 m/s)
        if location.speed > 89.4 {
            return false
        }
        
        // Filter out stale locations (> 15 seconds old)
        // This prevents the "teleport from home" bug when launching the app at work
        if -location.timestamp.timeIntervalSinceNow > 15 {
            return false
        }
        
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        
        for location in locations {
            // Validate location quality first
            guard isValidLocation(location) else { continue }
            
            // --- ANTI-DRIFT & JITTER FILTERING ---
            
            // 1. Speed Filtering:
            // Apple's speed can be jittery when sitting still.
            // We ignore anything below ~7.8 mph (3.5 m/s) to filter out GPS wander/walking.
            let reportedSpeed = max(0, location.speed)
            
            // Stricter movement filter: Must be moving > 3.5 m/s AND have good accuracy
            // This is aggressive to prevent "phantom mileage" while parked.
            let isMovingSpeed = reportedSpeed > 3.5
            let isAccurateEnough = location.horizontalAccuracy < 12
            
            // We only consider "Effectively Moving" if we have speed and accuracy
            let isMoving = isMovingSpeed && isAccurateEnough
            
            // Debounce/Consistency check could go here, but for now direct update
            self.isEffectivelyMoving = isMoving
            
            currentSpeedMph = isMoving ? (reportedSpeed * 2.23694) : 0
            
            // Update Diagnostics
            gpsAccuracy = location.horizontalAccuracy
            dataPointsCollected += 1
            trackingStatus = isMoving ? "Moving (\(Int(currentSpeedMph)) mph)" : "Stationary (Filtered)"
            
            // 2. Distance Filtering:
            // Only add distance if we are actually moving at a real speed
            // or if we have moved a significant distance (25m+) with high precision.
            
            if let lastLocation = lastValidLocation {
                let distance = location.distance(from: lastLocation)
                
                // Tighten Significant Move: Increase from 15m to 25m to be safer against drift
                let significantMovement = distance > 25 && location.horizontalAccuracy < 10
                
                if isMoving || significantMovement {
                    // Sanity check: prevent teleporting (> 500m jump)
                    if distance < 500 {
                        totalDistance += distance
                        lastValidLocation = location
                    }
                }
            } else {
                lastValidLocation = location
            }
            
            // Only publish the new location if we accepted the move (or it's the first one).
            // This prevents the map pin from jittering around when stationary.
            // We re-check the condition or simply check if lastValidLocation changed to this location?
            // Simpler: If we updated lastValidLocation, then update currentLocation.
            if lastValidLocation == location {
                 currentLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationTracker error: \(error.localizedDescription)")
        trackingStatus = "Error: \(error.localizedDescription)"
    }
}
