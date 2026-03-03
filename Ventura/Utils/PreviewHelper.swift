//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
struct PreviewHelper {
    
    // MARK: - Settings
    
    static func mockSettings() -> UserSettings {
        let s = UserSettings()
        s.homeLatitude = 41.256230458882776
        s.homeLongitude = -95.941144222386
        s.homeRadius = 150
        s.homeName = "Home"
        s.homeIcon = "house.fill"
        return s
    }
    
    static func mockSettingsNoHome() -> UserSettings {
        let s = UserSettings()
        // No home set
        return s
    }
    
    // MARK: - Session State
    
    static var mockActiveSessionState: SessionManager.ActiveSessionState {
        SessionManager.ActiveSessionState(
            totalDuration: 7245,        // ~2 hours
            timeAtHome: 1800,           // 30 min
            timeAway: 5445,             // ~1.5 hours
            distanceMeters: 48280,      // ~30 miles
            isSessionActive: true,
            netProfit: 47.82,
            netHourly: 23.75,
            netPerDistance: 1.59,
            deliveriesCount: 8,
            averageTip: 6.25
        )
    }
    
    static var mockSessionManager: SessionManager {
        let manager = SessionManager()
        manager.activeSessionState = mockActiveSessionState
        manager.cachedSettings = mockSettings()
        return manager
    }
    
    static var mockSessionManagerNoHome: SessionManager {
        let manager = SessionManager()
        manager.activeSessionState = mockActiveSessionState
        manager.cachedSettings = mockSettingsNoHome()
        return manager
    }
    
    static var mockRoute: [LocationData] {
        generateRoute(
            startLat: 41.256230458882776,
            startLon: -95.941144222386,
            points: 15
        )
    }
    
    // MARK: - View Models
    
    static var mockDashboardGraphViewModel: DashboardGraphViewModel {
        DashboardGraphViewModel(
            earningsPerHourData: [
                BarDataPoint(label: "Mon", value: 22.50),
                BarDataPoint(label: "Tue", value: 18.75),
                BarDataPoint(label: "Wed", value: 31.20),
                BarDataPoint(label: "Thu", value: 25.00),
                BarDataPoint(label: "Fri", value: 28.40),
                BarDataPoint(label: "Sat", value: 35.10),
                BarDataPoint(label: "Sun", value: 19.80),
            ],
            hoursWorkedData: [
                BarDataPoint(label: "Mon", value: 4.5),
                BarDataPoint(label: "Tue", value: 6.2),
                BarDataPoint(label: "Wed", value: 3.0),
                BarDataPoint(label: "Thu", value: 7.8),
                BarDataPoint(label: "Fri", value: 5.5),
                BarDataPoint(label: "Sat", value: 8.1),
                BarDataPoint(label: "Sun", value: 2.3),
            ],
            netEarningsData: [
                BarDataPoint(label: "Mon", value: 85.00),
                BarDataPoint(label: "Tue", value: 102.30),
                BarDataPoint(label: "Wed", value: 67.50),
                BarDataPoint(label: "Thu", value: 95.00),
                BarDataPoint(label: "Fri", value: 110.20),
                BarDataPoint(label: "Sat", value: 150.00),
                BarDataPoint(label: "Sun", value: 72.40),
            ]
        )
    }

    
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Session.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // Populate with data
        let sessions = generateMockSessions()
        for session in sessions {
            container.mainContext.insert(session)
        }
        
        // Also insert a default UserSettings if needed
        let settings = mockSettings()
        container.mainContext.insert(settings)
        
        return container
    }
    
    static func makeContainerNoHome() -> ModelContainer {
        let schema = Schema([
            Session.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // Populate with data
        let sessions = generateMockSessions()
        for session in sessions {
            container.mainContext.insert(session)
        }
        
        // Insert UserSettings without home
        let settings = mockSettingsNoHome()
        container.mainContext.insert(settings)
        
        return container
    }
    
    static func makeEmptyContainer() -> ModelContainer {
        let schema = Schema([
            Session.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // Populate only with settings, no sessions
        let settings = mockSettings()
        container.mainContext.insert(settings)
        
        return container
    }
    
    static func generateMockSessions(count: Int = 0) -> [Session] {
        var sessions: [Session] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Base coordinate 41.256230458882776, -95.941144222386
        let baseLat = 41.256230458882776
        let baseLon = -95.941144222386
        
        // Generate data over 4 years (approx 1460 days) to test all chart ranges
        // Strategy:
        // - Last 60 days: High frequency (near daily)
        // - 60 days to 1 year: Medium frequency (2-3 times a week)
        // - 1 year to 4 years: Low frequency (once a week or so)
        
        let totalDays = 365 * 4 + 60 
        
        for dayOffset in 0..<totalDays {
            // Determine probability based on how recent the day is
            let probability: Double
            if dayOffset < 60 {
                probability = 0.8 // 80% chance of working on a recent day
            } else if dayOffset < 365 {
                probability = 0.4 // 40% chance
            } else {
                probability = 0.1 // 10% chance
            }
            
            if Double.random(in: 0...1) < probability {
                // Generate a session for this day
                // To simulate realistic times, subtract days from now
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
                
                // Random start time between 8 AM and 8 PM
                let hourOffset = Double.random(in: 8...20) * 3600
                let start = calendar.startOfDay(for: date).addingTimeInterval(hourOffset)
                
                let duration = Double.random(in: 1800...28800) // 30 mins to 8 hours
                let end = start.addingTimeInterval(duration)
                
                // Create a mock user settings for this session
                let mockSettings = UserSettings()
                // Slowly increase wage over time (inflation/raises) ?? No, just random variation
                mockSettings.hourlyWage = Double.random(in: 18.0...35.0).rounded(to: 2)
                mockSettings.mpg = Double.random(in: 22.0...32.0).rounded(to: 1)
                
                let session = Session(startTimestamp: start, userSettings: mockSettings)
                session.endTimestamp = end
                
                // Random stats scaled by duration
                let durationHours = duration / 3600.0
                session.deliveriesCount = Int(Double.random(in: 1.5...4.0) * durationHours)
                session.gpsDistanceMeters = Double.random(in: 10000...25000) * durationHours // 10-25km per hour
                
                // Random tips
                let tipCount = Int(Double(session.deliveriesCount) * 0.8) // 80% tip rate
                for _ in 0..<tipCount {
                    let randomTip = Decimal(Double.random(in: 2.0...20.0)).rounded(2)
                    let cents = Decimal(Double.random(in: 0.01...0.99))
                    session.tips.append(randomTip + cents)
                }
                
                // Generate a random route (simplified)
                session.route = generateRoute(
                    startLat: baseLat + Double.random(in: -0.05...0.05),
                    startLon: baseLon + Double.random(in: -0.05...0.05),
                    points: 5 // Keep points low for memory in preview
                )
                
                // Force calculations
                _ = session.grossEarnings
                
                sessions.append(session)
            }
        }
        
        return sessions.sorted { $0.startTimestamp > $1.startTimestamp } // Return sorted
    }
    
    static func generateRoute(startLat: Double, startLon: Double, points: Int) -> [LocationData] {
        var route: [LocationData] = []
        var currentLat = startLat
        var currentLon = startLon
        
        for i in 0..<points {
            let loc = LocationData(
                latitude: currentLat,
                longitude: currentLon,
                timestamp: Date().addingTimeInterval(Double(i) * 60), // 1 min apart
                speed: Double.random(in: 10...60), // Random speed mph
                altitude: 0
            )
            route.append(loc)
            
            // Move randomly
            currentLat += Double.random(in: -0.002...0.002)
            currentLon += Double.random(in: -0.002...0.002)
        }
        
        return route
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var result = self
        var localSelf = self
        NSDecimalRound(&result, &localSelf, scale, .plain)
        return result
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}




