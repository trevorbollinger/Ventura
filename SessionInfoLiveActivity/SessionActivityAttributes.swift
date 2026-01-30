//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//


import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state that changes over time
        var totalEarnings: Double
        var netProfit: Double
        var netHourlyProfit: Double
        var deliveryCount: Int
        var totalMiles: Double
        var lastUpdated: Date
    }

    // Fixed non-changing properties about the activity go here!
    var startTime: Date
}
