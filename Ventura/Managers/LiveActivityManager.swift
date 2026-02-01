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
    
    func start(session: Session) {
        // Check for existing activity first to recover state
        if activity == nil {
            if let existingActivity = Activity<SessionActivityAttributes>.activities.first {
                self.activity = existingActivity
                print("Recovered existing Live Activity: \(existingActivity.id)")
                update(session: session) // Immediate update on recovery
                return
            }
        }

        // Ensure we don't start multiple activities
        guard activity == nil else {
            update(session: session)
            return
        }
        
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = SessionActivityAttributes(startTime: session.startTimestamp)
        let contentState = SessionActivityAttributes.ContentState(
            totalEarnings: NSDecimalNumber(decimal: session.grossEarnings).doubleValue,
            netProfit: NSDecimalNumber(decimal: session.netProfit).doubleValue,
            netHourlyProfit: NSDecimalNumber(decimal: session.earningsPerHour).doubleValue,
            deliveryCount: session.deliveriesCount,
            totalMiles: session.totalMiles,
            lastUpdated: Date()
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
    
    func update(session: Session) {
        guard let activity = activity else { return }
        
        let contentState = SessionActivityAttributes.ContentState(
            totalEarnings: NSDecimalNumber(decimal: session.grossEarnings).doubleValue,
            netProfit: NSDecimalNumber(decimal: session.netProfit).doubleValue,
            netHourlyProfit: NSDecimalNumber(decimal: session.earningsPerHour).doubleValue,
            deliveryCount: session.deliveriesCount,
            totalMiles: session.totalMiles,
            lastUpdated: Date()
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
                deliveryCount: activity.content.state.deliveryCount,
                totalMiles: activity.content.state.totalMiles,
                lastUpdated: Date()
            )
            let finalContent = ActivityContent(state: contentState, staleDate: nil)
            
            await activity.end(finalContent, dismissalPolicy: .immediate)
            self.activity = nil // Clear reference
            print("Live Activity ended")
        }
    }
}
