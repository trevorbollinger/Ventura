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
        totalDistance = 0.0
        dataPointsCollected = 0
        lastValidLocation = nil
        
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
            // We ignore anything below ~2.2 mph (1.0 m/s) to show 0 mph when stationary.
            let reportedSpeed = max(0, location.speed)
            let isEffectivelyMoving = reportedSpeed > 1.0 
            
            currentSpeedMph = isEffectivelyMoving ? (reportedSpeed * 2.23694) : 0
            
            // Update Diagnostics
            gpsAccuracy = location.horizontalAccuracy
            dataPointsCollected += 1
            trackingStatus = "Recording (±\(Int(location.horizontalAccuracy))m)"
            
            // 2. Distance Filtering:
            // Only add distance if we are actually moving at a real speed (> 2.2 mph)
            // or if we have moved a significant distance (15m+) with high precision.
            if let lastLocation = lastValidLocation {
                let distance = location.distance(from: lastLocation)
                
                // We add distance only if:
                // - We are moving at a driveable speed (> 2.2 mph)
                // - OR we have moved a significant distance with good accuracy
                let significantMovement = distance > 15 && location.horizontalAccuracy < 20
                
                if (isEffectivelyMoving || significantMovement) && distance < 1000 {
                    totalDistance += distance
                }
            }
            
            lastValidLocation = location
            currentLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationTracker error: \(error.localizedDescription)")
        trackingStatus = "Error: \(error.localizedDescription)"
    }
}
