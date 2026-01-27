//
//  PermissionManager.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//
import Foundation
import CoreLocation
import CoreMotion
import Combine
import UserNotifications

class PermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PermissionManager()
    
    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()
    
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var backgroundLocationEnabled: Bool = false
    @Published var motionStatus: String = "Waiting for data..."
    @Published var motionPermissionStatus: String = "Undetermined"
    @Published var isMoving: Bool = false
    @Published var motionConfidence: String = "N/A"
    @Published var rawMotionFlags: [String: Bool] = [:]
    
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        self.locationStatus = locationManager.authorizationStatus
        
        checkMotionAuthorization()
        checkNotificationAuthorization()
    }
    
    func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    private func checkMotionAuthorization() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            self.motionPermissionStatus = "Authorized"
            startMotionUpdates()
        case .denied:
            self.motionPermissionStatus = "Denied"
        case .restricted:
            self.motionPermissionStatus = "Restricted"
        case .notDetermined:
            self.motionPermissionStatus = "Undetermined"
        @unknown default:
            self.motionPermissionStatus = "Unknown"
        }
    }


    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestBackgroundLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestMotionPermission() {
        // CMMotionActivityManager doesn't have a direct "requestPermission" method
        // It requests when you first try to start updates.
        startMotionUpdates()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.checkNotificationAuthorization()
            }
        }
    }

    func startMotionUpdates() {
        if CMMotionActivityManager.isActivityAvailable() {
            motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity = activity else { return }
                DispatchQueue.main.async {
                    self?.motionPermissionStatus = "Authorized"
                    self?.isMoving = activity.automotive
                    self?.motionStatus = self?.getActivityString(activity) ?? "Unknown"
                    self?.motionConfidence = self?.getConfidenceString(activity.confidence) ?? "N/A"
                    self?.rawMotionFlags = [
                        "Automotive": activity.automotive,
                        "Stationary": activity.stationary,
                        "Walking": activity.walking,
                        "Running": activity.running,
                        "Cycling": activity.cycling,
                        "Unknown": activity.unknown
                    ]
                }
            }
        } else {
            motionPermissionStatus = "Not Available"
        }
    }
    

    private func getActivityString(_ activity: CMMotionActivity) -> String {
        if activity.automotive { return "Driving / In Vehicle" }
        if activity.stationary { return "Stationary" }
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.cycling { return "Cycling" }
        if activity.unknown { return "Unknown State" }
        return "Not determined"
    }

    private func getConfidenceString(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        @unknown default: return "Unknown"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationStatus = manager.authorizationStatus
            // Check if 'Always' is granted for background location
            self.backgroundLocationEnabled = (manager.authorizationStatus == .authorizedAlways)
        }
    }
}
