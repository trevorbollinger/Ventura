//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import Foundation

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    // Hold reference to the current activity
    private var activity: Activity<SessionActivityAttributes>?
    
    private init() {}
    
    func start(session: Session, settings: UserSettings) {
        // Check for existing activity first to recover state
        if activity == nil {
            if let existingActivity = Activity<SessionActivityAttributes>.activities.first {
                self.activity = existingActivity
                print("Recovered existing Live Activity: \(existingActivity.id)")
                update(session: session, settings: settings) // Immediate update on recovery
                return
            }
        }

        // Ensure we don't start multiple activities
        guard activity == nil else {
            update(session: session, settings: settings)
            return
        }
        
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        // Use CURRENT settings for display (not session snapshot)
        let displayDistance = settings.displayDistance(miles: session.totalMiles)
        let perMile = session.totalMiles > 0 ? Double(truncating: session.netPerMile as NSNumber) : 0
        let displayPerDistance = settings.displayPerDistance(perMile: perMile)
        
        let attributes = SessionActivityAttributes(
            startTime: session.startTimestamp
        )
        let contentState = SessionActivityAttributes.ContentState(
            totalEarnings: NSDecimalNumber(decimal: session.grossEarnings).doubleValue,
            netProfit: NSDecimalNumber(decimal: session.netProfit).doubleValue,
            netHourlyProfit: NSDecimalNumber(decimal: session.earningsPerHour).doubleValue,
            netPerDistance: displayPerDistance,
            deliveryCount: session.deliveriesCount,
            totalDistance: displayDistance,
            lastUpdated: Date(),
            currencyCode: settings.currencyCode,
            distanceUnitRaw: settings.distanceUnitRaw
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("Live Activity started with ID: \(activity?.id ?? "unknown")")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func update(session: Session, settings: UserSettings) {
        guard let activity = activity else { return }
        
        // Use CURRENT settings for display
        let displayDistance = settings.displayDistance(miles: session.totalMiles)
        let perMile = session.totalMiles > 0 ? Double(truncating: session.netPerMile as NSNumber) : 0
        let displayPerDistance = settings.displayPerDistance(perMile: perMile)
        
        let contentState = SessionActivityAttributes.ContentState(
            totalEarnings: NSDecimalNumber(decimal: session.grossEarnings).doubleValue,
            netProfit: NSDecimalNumber(decimal: session.netProfit).doubleValue,
            netHourlyProfit: NSDecimalNumber(decimal: session.earningsPerHour).doubleValue,
            netPerDistance: displayPerDistance,
            deliveryCount: session.deliveriesCount,
            totalDistance: displayDistance,
            lastUpdated: Date(),
            currencyCode: settings.currencyCode,
            distanceUnitRaw: settings.distanceUnitRaw
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    func end() {
        guard let activity = activity else { return }
        
        // End immediately
        Task {
            let contentState = SessionActivityAttributes.ContentState(
                totalEarnings: activity.content.state.totalEarnings,
                netProfit: activity.content.state.netProfit,
                netHourlyProfit: activity.content.state.netHourlyProfit,
                netPerDistance: activity.content.state.netPerDistance,
                deliveryCount: activity.content.state.deliveryCount,
                totalDistance: activity.content.state.totalDistance,
                lastUpdated: Date(),
                currencyCode: activity.content.state.currencyCode,
                distanceUnitRaw: activity.content.state.distanceUnitRaw
            )
            let finalContent = ActivityContent(state: contentState, staleDate: nil)
            
            await activity.end(finalContent, dismissalPolicy: .immediate)
            self.activity = nil // Clear reference
            print("Live Activity ended")
        }
    }
}
