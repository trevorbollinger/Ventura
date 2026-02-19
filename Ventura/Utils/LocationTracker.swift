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
    
    // --- Debug / Diagnostics (consolidated to reduce @Published emissions) ---
    struct Diagnostics {
        var trackingStatus: String = "Idle"
        var gpsAccuracy: Double = 0.0
        var currentSpeedMph: Double = 0.0
        var dataPointsCollected: Int = 0
        var isEffectivelyMoving: Bool = false
    }
    @Published var diagnostics = Diagnostics()
    
    private var trackingStartTime: Date?
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
        trackingStartTime = Date() // Mark the exact start time
        
        // Do NOT reset totalDistance here, as we may be restoring an existing session.
        // resetDistance() should be called explicitly for new sessions.
        
        // Enforce maximum accuracy for tracking session
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10 // Capture updates every 10 meters - Sweet spot for accuracy vs data size
        locationManager.startUpdatingLocation()
        
        diagnostics.trackingStatus = "Active (High Precision)"
        print("📍 Started high-precision tracking at \(trackingStartTime!)")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        trackingStartTime = nil
        locationManager.stopUpdatingLocation()
        lastValidLocation = nil
        currentLocation = nil // Clear UI state to prevent showing old location on next start
        diagnostics.trackingStatus = "Stopped"
        print("📍 Stopped tracking")
    }

    func resetDistance() {
        totalDistance = 0.0
        lastValidLocation = nil
        diagnostics = Diagnostics(trackingStatus: "Distance Reset")
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
        
        // STRICT TIMESTAMP FILTER:
        if let startTime = trackingStartTime {
            if location.timestamp < startTime {
                // Reject stale locations from before the session started
                return false
            }
        }
        
        // Filter out very poor accuracy (e.g. > 50 meters)
        if location.horizontalAccuracy > 50 {
            return false
        }
        
        // Filter unrealistic speeds (> 200 mph = 89.4 m/s)
        if location.speed > 89.4 {
            return false
        }
        
        // Filter out stale locations (> 15 seconds old)
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
            
            let speedMph = isMoving ? (reportedSpeed * 2.23694) : 0
            
            // Update all diagnostics in a single @Published write
            diagnostics = Diagnostics(
                trackingStatus: isMoving ? "Moving (\(Int(speedMph)) mph)" : "Stationary (Filtered)",
                gpsAccuracy: location.horizontalAccuracy,
                currentSpeedMph: speedMph,
                dataPointsCollected: diagnostics.dataPointsCollected + 1,
                isEffectivelyMoving: isMoving
            )
            
            // 2. Distance Filtering:
            // Only add distance if we are actually moving at a real speed
            // or if we have moved a significant distance (25m+) with high precision.
            
            if let lastLocation = lastValidLocation {
                let distance = location.distance(from: lastLocation)
                let timeDelta = location.timestamp.timeIntervalSince(lastLocation.timestamp)
                
                // Tighten Significant Move: Increase from 15m to 25m to be safer against drift
                let significantMovement = distance > 25 && location.horizontalAccuracy < 10
                
                if isMoving || significantMovement {
                    // DYNAMIC GUARD (Tunnel Support):
                    // Instead of a hard 500m limit, we allow 500m + (Time * MaxSpeed).
                    // If you are in a tunnel for 60s at 30m/s, you move 1800m. The old 500m limit would block this.
                    // We assume a max legitimate speed of ~60 m/s (134 mph) for the buffer.
                    let dynamicBuffer = 500.0 + (max(0, timeDelta) * 60.0)
                    
                    if distance < dynamicBuffer {
                        totalDistance += distance
                        lastValidLocation = location
                    } else if totalDistance < 100 {
                         // "Snap-to-Reality" Fix:
                        // If we are just starting the session (low distance) and see a huge jump,
                        // it's likely the first point was a "wrong anchor" (fresh timestamp, stale coords).
                        // We accept the new location as the true start point, but DO NOT add the huge jump distance.
                        print("📍 [Tracker] Snap-to-Reality triggered. Correcting start location (Jump: \(Int(distance))m)")
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
        diagnostics.trackingStatus = "Error: \(error.localizedDescription)"
    }
}
