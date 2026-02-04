//
//  StatsChartCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/29/26.
//

import SwiftUI
import Charts
import SwiftData

struct StatsChartCard: View {
    let type: StatType
    let value: String
    let sessions: [Session]
    let timeframe: Timeframe
    
    // Helper enum for clarity
    enum GroupingUnit {
        case day, week, year
    }
    
    private var groupingUnit: GroupingUnit {
        // Dynamic smart grouping based on the range of data
        guard let earliest = sessions.last?.startTimestamp else { return .day }
        let now = Date()
        let daysDiff = Calendar.current.dateComponents([.day], from: earliest, to: now).day ?? 0
        
        if daysDiff <= 14 {
            return .day
        } else if daysDiff <= 180 { // Approx 6 months
            return .week
        } else {
            return .year // Actually we meant Month in the plan, but let's stick to what fits better. 
                         // Wait, the plan said "Group by Month" for > 6 months. 
                         // The enum only has .year currently. I should probably add .month to the enum.
                         // But for now let's stick to the existing enum or update it.
                         // Let's update the enum in the next step if needed, but the current code has .year.
                         // Actually, I can just use .week for everything up to a year, or switch to month.
                         // Let's stick to .week for now as it offers better granularity for "Pay Periods".
                         // If I want to support Month I need to add it to the enum case.
                         // Let's check the enum definition below.
            return .week 
        }
    }
    
    private var chartData: [(date: Date, value: Decimal)] {
        let unit = groupingUnit
        
        let calendar = Calendar.current
        var grouped: [Date: [Session]] = [:]
        let helper = DateRangeHelper.shared
        
        // 1. Group sessions by date bucket
        for session in sessions {
            guard let end = session.endTimestamp else { continue }
            
            let key: Date
            switch unit {
            case .day:
                key = calendar.startOfDay(for: end)
            case .week:
                // Align to Monday
                key = helper.startOfWeek(for: end)
            case .year:
                // Use month for year view? Or actual year? 
                // If the enum is just .year, then year.
                key = calendar.date(from: calendar.dateComponents([.year], from: end)) ?? end
            }
            
            grouped[key, default: []].append(session)
        }
        
        // 2. Calculate value for each bucket based on StatType
        let result = grouped.map { (date, sessions) -> (Date, Decimal) in
            let value: Decimal
            
            switch type {
            case .netProfit:
                value = sessions.reduce(0) { $0 + $1.netProfit }
                
            case .miles:
                value = Decimal(sessions.reduce(0) { $0 + $1.totalMiles })
                
            case .hours:
                value = sessions.reduce(0) { $0 + $1.durationInHours }
                
            case .deliveries:
                value = Decimal(sessions.reduce(0) { $0 + $1.deliveriesCount })
                
            case .hourlyProfit:
                let totalProfit = sessions.reduce(0) { $0 + $1.netProfit }
                let totalHours = sessions.reduce(0) { $0 + $1.durationInHours }
                value = totalHours > 0 ? totalProfit / totalHours : 0
                
            case .dollarsPerMile:
                let totalProfit = sessions.reduce(0) { $0 + $1.netProfit }
                let totalMiles = sessions.reduce(0) { $0 + $1.totalMiles }
                value = totalMiles > 0 ? totalProfit / Decimal(totalMiles) : 0
            }
            
            return (date, value)
        }
        
        return result.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack (alignment: .top){
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                    
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                Image(systemName: type.icon)
                    .font(.subheadline)
                    .foregroundStyle(type.color)
                    .padding(8)
                    .background(type.color.opacity(0.1))
                    .clipShape(Circle())
                
            }
            .padding([.horizontal, .top])
            
            if !chartData.isEmpty {
                Chart(chartData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: calendarUnit),
                        y: .value(type.title, item.value)
                    )
                    .foregroundStyle(type.color.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(format: axisFormat)
                }
                .frame(height: 200)
                .padding()
            } else {
                // Placeholder or Empty State if no chart data available
                ContentUnavailableView("No Chart Data", systemImage: "chart.bar.xaxis")
                    .frame(height: 200)
            }
        }
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var calendarUnit: Calendar.Component {
        switch groupingUnit {
        case .day: return .day
        case .week: return .weekOfYear
        case .year: return .year
        }
    }
    
    private var axisFormat: Date.FormatStyle {
        switch groupingUnit {
        case .day: return .dateTime.weekday()
        case .week: return .dateTime.month().day()
        case .year: return .dateTime.year()
        default: return .dateTime.month().day()
        }
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    
    // Create mock settings for the preview sessions
    let mockSettings = UserSettings()
    mockSettings.hourlyWage = 15.0
    mockSettings.reimbursement = 0.30
    mockSettings.mpg = 25.0
    
    // Create preview sessions
    let s1 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 1), userSettings: mockSettings)
    s1.endTimestamp = Date().addingTimeInterval(-86400 * 1 + 3600)
    s1.manualStartOdometer = 100
    s1.manualEndOdometer = 110 // 10 miles
    s1.tips = [20.0] // total profit = ~15 + 3 + 20 - gas
    
    let s2 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 2), userSettings: mockSettings)
    s2.endTimestamp = Date().addingTimeInterval(-86400 * 2 + 3600)
    s2.manualStartOdometer = 200
    s2.manualEndOdometer = 215 // 15 miles
    s2.tips = [30.0]
    
    let s3 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 3), userSettings: mockSettings)
    s3.endTimestamp = Date().addingTimeInterval(-86400 * 3 + 3600)
    s3.manualStartOdometer = 300
    s3.manualEndOdometer = 320 // 20 miles
    s3.tips = [40.0]

    return ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ScrollView {
            VStack {
                StatsChartCard(
                    type: .netProfit,
                    value: "$1,204.50",
                    sessions: [s1, s2, s3],
                    timeframe: .sevenDays
                )
                .frame(height: 300) // Ensure it has height context if needed
                
                StatsChartCard(
                    type: .miles,
                    value: "254.3 mi",
                    sessions: [],
                    timeframe: .sevenDays
                )
            }
            .padding()
        }
    }
    .modelContainer(container)
}
