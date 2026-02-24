//
//  StatsCalculator.swift
//  Ventura
//

import Foundation
import SwiftData

struct StatsCalculator {
    nonisolated static func computeStats(sessions: [Session], timeframe: Timeframe, settings: UserSettings) -> StatsCache {
        let helper = DateRangeHelper(weekStartDay: settings.weekStartDay)
        let now = Date()
        
        // Filter sessions
        let filteredSessions = sessions.filter { session in
            guard let end = session.endTimestamp else { return false }
            switch timeframe {
            case .oneDay: return Calendar.current.isDateInToday(end)
            case .sevenDays: return end >= helper.startOfCurrentWeek
            case .twoWeeks: return end >= helper.startOfWeeksAgo(1)
            case .fiveWeeks: return end >= helper.startOfWeeksAgo(4)
            case .thirteenWeeks: return end >= helper.startOfWeeksAgo(12)
            case .fiftyTwoWeeks: return end >= helper.startOfWeeksAgo(51)
            case .all: return true
            }
        }
        
        // Calculate primitives
        let totalNetProfit = filteredSessions.reduce(0) { $0 + $1.netProfit }
        let totalMiles = filteredSessions.reduce(0) { $0 + $1.totalMiles }
        let totalHours = filteredSessions.reduce(0) { $0 + $1.durationInHours }
        let totalDeliveries = filteredSessions.reduce(0) { $0 + $1.deliveriesCount }
        
        let avgHourlyRate: Decimal = totalHours > 0 ? totalNetProfit / totalHours : 0
        
        var avgDollarsPerMile: Decimal = 0
         if totalMiles > 0 {
            let profitPerMile = totalNetProfit / Decimal(totalMiles)
            if settings.distanceUnit == .kilometers {
                avgDollarsPerMile = profitPerMile / 1.60934
            } else {
                avgDollarsPerMile = profitPerMile
            }
        }
        
        // Date Range Text
        var dateRangeText = "No Data"
        if !filteredSessions.isEmpty {
            switch timeframe {
            case .oneDay:
                dateRangeText = now.formatted(date: .abbreviated, time: .omitted)
            case .sevenDays:
                dateRangeText = "This Week"
            case .all:
                if let earliest = filteredSessions.last?.startTimestamp {
                    dateRangeText = "Since \(earliest.formatted(date: .abbreviated, time: .omitted))"
                } else {
                    dateRangeText = "All Time"
                }
            default:
                let start: Date
                switch timeframe {
                case .twoWeeks: start = helper.startOfWeeksAgo(1)
                case .fiveWeeks: start = helper.startOfWeeksAgo(4)
                case .thirteenWeeks: start = helper.startOfWeeksAgo(12)
                case .fiftyTwoWeeks: start = helper.startOfWeeksAgo(51)
                default: start = now
                }
                dateRangeText = helper.formatRange(start, now)
            }
        }
        
        // Calculate Chart Data
        var chartData: [String: [ChartDataPoint]] = [:]
        
        // Grouping unit
        enum GroupingUnit { case day, week, year }
        var groupingUnit: GroupingUnit = .day
        
        if let earliest = filteredSessions.last?.startTimestamp {
            let daysDiff = Calendar.current.dateComponents([.day], from: earliest, to: now).day ?? 0
            if daysDiff <= 14 { groupingUnit = .day }
            else if daysDiff <= 180 { groupingUnit = .week }
            else { groupingUnit = .year }
        }
        
        let calendar = Calendar.current
        var grouped: [Date: [Session]] = [:]
        
        for session in filteredSessions {
            guard let end = session.endTimestamp else { continue }
            let key: Date
            switch groupingUnit {
            case .day: key = calendar.startOfDay(for: end)
            case .week: key = helper.startOfWeek(for: end)
            case .year: key = calendar.date(from: calendar.dateComponents([.year], from: end)) ?? end
            }
            grouped[key, default: []].append(session)
        }
        
        let distanceUnit = settings.distanceUnit
        
        for type in StatType.allCases {
            let points = grouped.map { (date, sessions) -> ChartDataPoint in
                let value: Decimal
                switch type {
                case .netProfit:
                    value = sessions.reduce(0) { $0 + $1.netProfit }
                case .miles:
                    let miles = sessions.reduce(0) { $0 + $1.totalMiles }
                    value = distanceUnit == .kilometers ? Decimal(miles * 1.60934) : Decimal(miles)
                case .hours:
                    value = sessions.reduce(0) { $0 + $1.durationInHours }
                case .deliveries:
                    value = Decimal(sessions.reduce(0) { $0 + $1.deliveriesCount })
                case .hourlyProfit:
                    let tp = sessions.reduce(0) { $0 + $1.netProfit }
                    let th = sessions.reduce(0) { $0 + $1.durationInHours }
                    value = th > 0 ? tp / th : 0
                case .dollarsPerMile:
                    let tp = sessions.reduce(0) { $0 + $1.netProfit }
                    let tm = sessions.reduce(0) { $0 + $1.totalMiles }
                    let pm = tm > 0 ? tp / Decimal(tm) : 0
                    value = distanceUnit == .kilometers ? pm / 1.60934 : pm
                }
                return ChartDataPoint(date: date, value: value)
            }.sorted { $0.date < $1.date }
            
            chartData[type.id] = points
        }
        
        return StatsCache(
            netProfit: totalNetProfit,
            totalMiles: totalMiles,
            totalHours: totalHours,
            deliveries: totalDeliveries,
            hourlyProfit: avgHourlyRate,
            dollarsPerMile: avgDollarsPerMile,
            dateRangeText: dateRangeText,
            chartData: chartData
        )
    }
}
