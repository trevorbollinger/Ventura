//
//  StatsCache.swift
//  Ventura
//

import Foundation
import SwiftUI

enum Timeframe: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "Today"
    case sevenDays = "Week"
    case twoWeeks = "2W"
    case fiveWeeks = "5W"
    case thirteenWeeks = "13W"
    case fiftyTwoWeeks = "52W"
    case all = "All"
    
    var id: String { rawValue }
}

enum StatType: String, CaseIterable, Identifiable, Sendable {
    case netProfit = "Net Profit"
    case miles = "Total Miles"
    case hours = "Hours Worked"
    case deliveries = "Deliveries"
    case hourlyProfit = "Hourly Profit"
    case dollarsPerMile = "$ / Mile"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .netProfit: return "dollarsign.circle.fill"
        case .miles: return "location.circle.fill"
        case .hours: return "clock.fill"
        case .deliveries: return "box.truck.badge.clock.fill"
        case .hourlyProfit: return "speedometer"
        case .dollarsPerMile: return "fuelpump.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .netProfit: return .green
        case .miles: return .blue
        case .hours: return .orange
        case .deliveries: return .purple
        case .hourlyProfit: return .teal
        case .dollarsPerMile: return .red
        }
    }
    
    var title: String { rawValue }
}

struct ChartDataPoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    let date: Date
    let value: Decimal
}

struct StatsCache: Sendable {
    var netProfit: Decimal = 0
    var totalMiles: Double = 0
    var totalHours: Decimal = 0
    var deliveries: Int = 0
    var hourlyProfit: Decimal = 0
    var dollarsPerMile: Decimal = 0
    var dateRangeText: String = "No Data"
    var chartData: [String: [ChartDataPoint]] = [:]
}
