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
    private var lastPushDate: Date?
    
    private init() {}
    
    func start(session: Session, settings: UserSettings) {
        // Check for existing activity first to recover state
        if activity == nil {
            if let existingActivity = Activity<SessionActivityAttributes>.activities.first {
                self.activity = existingActivity
                print("Recovered existing Live Activity: \(existingActivity.id)")
                update(session: session, settings: settings, force: true) // Immediate update on recovery
                return
            }
        }

        // Ensure we don't start multiple activities
        guard activity == nil else {
            update(session: session, settings: settings, force: true)
            return
        }
        
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let contentState = LiveActivityManager.buildContentState(session: session, settings: settings)
        
        let attributes = SessionActivityAttributes(
            startTime: session.startTimestamp
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastPushDate = Date()
            print("Live Activity started with ID: \(activity?.id ?? "unknown")")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func update(session: Session, settings: UserSettings, force: Bool = false) {
        let state = LiveActivityManager.buildContentState(session: session, settings: settings)
        update(state: state, force: force)
    }
    
    func update(state: SessionActivityAttributes.ContentState, force: Bool = false) {
        guard let activity = activity else { return }
        
        // Throttling: Only update if forced OR >5 seconds have passed
        if !force, let last = lastPushDate, Date().timeIntervalSince(last) < 1 {
            return
        }
        
        let content = ActivityContent(state: state, staleDate: nil)
        
        Task {
            await activity.update(content)
            self.lastPushDate = Date()
            if force { print("⚡️ Live Activity Forced Update") }
        }
    }
    
    // Helper to build state from Session (for convenience)
    static func buildContentState(session: Session, settings: UserSettings) -> SessionActivityAttributes.ContentState {
        // Use CURRENT settings for display
        let displayDistance = settings.displayDistance(miles: session.totalMiles)
        let perMile = session.totalMiles > 0 ? Double(truncating: session.netPerMile as NSNumber) : 0
        let displayPerDistance = settings.displayPerDistance(perMile: perMile)
        
        return SessionActivityAttributes.ContentState(
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
