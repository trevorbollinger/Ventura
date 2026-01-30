//
//  RateConflictSheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftData
import Foundation

/// Utility for validating and combining multiple sessions
struct SessionCombiner {
    
    /// Validates if sessions can be combined and returns conflicting fields if not
    static func canCombine(_ sessions: [Session]) -> (canCombine: Bool, conflictingFields: [String]?) {
        guard sessions.count >= 2 else {
            return (false, nil)
        }
        
        // Use the first session as reference
        let reference = sessions[0]
        var allConflicts = Set<String>()
        
        // Check each session against the reference
        for session in sessions.dropFirst() {
            let conflicts = reference.ratesDifferingFrom(session)
            allConflicts.formUnion(conflicts)
        }
        
        if allConflicts.isEmpty {
            return (true, nil)
        } else {
            return (false, Array(allConflicts).sorted())
        }
    }
    
    /// Combines multiple sessions into a single session
    /// - Parameters:
    ///   - sessions: Sessions to combine (must have matching rates)
    ///   - modelContext: SwiftData model context for database operations
    /// - Returns: The newly created combined session
    static func combine(_ sessions: [Session], in modelContext: ModelContext) -> Session {
        guard sessions.count >= 2 else {
            fatalError("Cannot combine fewer than 2 sessions")
        }
        
        // Sort sessions by start time to get earliest and latest
        let sortedSessions = sessions.sorted { $0.startTimestamp < $1.startTimestamp }
        let earliest = sortedSessions.first!
        let latest = sortedSessions.last!
        
        // Create new session with the reference session's rates (use earliest)
        let combined = Session(startTimestamp: earliest.startTimestamp, userSettings: UserSettings())
        
        // Manually set all rate fields from the earliest session
        combined.hourlyWage = earliest.hourlyWage
        combined.passiveWage = earliest.passiveWage
        combined.perDeliveryRate = earliest.perDeliveryRate
        combined.mileageReimbursementRate = earliest.mileageReimbursementRate
        combined.vehicleMPG = earliest.vehicleMPG
        combined.fuelPrice = earliest.fuelPrice
        combined.wageTypeRaw = earliest.wageTypeRaw
        combined.reimbursementTypeRaw = earliest.reimbursementTypeRaw
        
        // Set time range
        combined.endTimestamp = latest.endTimestamp
        
        // Combine all tips
        combined.tips = sessions.flatMap { $0.tips }
        
        // Sum deliveries count
        combined.deliveriesCount = sessions.reduce(0) { $0 + $1.deliveriesCount }
        
        // Sum GPS distance
        combined.gpsDistanceMeters = sessions.reduce(0.0) { $0 + $1.gpsDistanceMeters }
        
        // Combine and sort routes by timestamp
        let allRoutePoints = sessions.flatMap { $0.route }
        combined.route = allRoutePoints.sorted { $0.timestamp < $1.timestamp }
        
        // Handle manual odometer readings
        // Use earliest session's start odometer and latest session's end odometer
        combined.manualStartOdometer = earliest.manualStartOdometer
        combined.manualEndOdometer = latest.manualEndOdometer
        
        // Add combined session to context
        modelContext.insert(combined)
        
        // Delete original sessions
        for session in sessions {
            modelContext.delete(session)
        }
        
        return combined
    }
    
    /// Groups sessions by their rate info to show unique rate combinations
    static func groupByRates(_ sessions: [Session]) -> [Session.RateInfo: [Session]] {
        var groups: [Session.RateInfo: [Session]] = [:]
        
        for session in sessions {
            let rateInfo = session.rateInfo
            if groups[rateInfo] == nil {
                groups[rateInfo] = []
            }
            groups[rateInfo]?.append(session)
        }
        
        return groups
    }
}
