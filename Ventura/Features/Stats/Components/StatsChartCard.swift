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
    let chartDataPoints: [ChartDataPoint]
    let timeframe: Timeframe
    let currencyCode: String
    let distanceUnit: DistanceUnit
    let weekStartDay: WeekStartDay
    
    // Helper enum for clarity
    enum GroupingUnit {
        case day, week, year
    }
    
    private var groupingUnit: GroupingUnit {
        guard let earliest = chartDataPoints.first?.date else { return .day }
        let now = Date()
        let daysDiff = Calendar.current.dateComponents([.day], from: earliest, to: now).day ?? 0
        
        if daysDiff <= 14 {
            return .day
        } else if daysDiff <= 180 {
            return .week
        } else {
            return .year
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
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
            
            if !chartDataPoints.isEmpty {
                Chart(chartDataPoints, id: \.date) { item in
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
        }
    }
}

struct StatsChartCardPreviewHelper: View {
    let container = PreviewHelper.makeContainer()
    
    private func makeSessions() -> [Session] {
        let mockSettings = UserSettings()
        mockSettings.hourlyWage = 15.0
        mockSettings.reimbursement = 0.30
        mockSettings.mpg = 25.0
        
        let s1 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 1), userSettings: mockSettings)
        s1.endTimestamp = Date().addingTimeInterval(-86400 * 1 + 3600)
        s1.manualStartOdometer = 100
        s1.manualEndOdometer = 110
        s1.tips = [20.0]
        
        let s2 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 2), userSettings: mockSettings)
        s2.endTimestamp = Date().addingTimeInterval(-86400 * 2 + 3600)
        s2.manualStartOdometer = 200
        s2.manualEndOdometer = 215
        s2.tips = [30.0]
        
        let s3 = Session(startTimestamp: Date().addingTimeInterval(-86400 * 3), userSettings: mockSettings)
        s3.endTimestamp = Date().addingTimeInterval(-86400 * 3 + 3600)
        s3.manualStartOdometer = 300
        s3.manualEndOdometer = 320
        s3.tips = [40.0]
        
        return [s1, s2, s3]
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack {
                    StatsChartCard(
                        type: .netProfit,
                        value: "$1,204.50",
                        chartDataPoints: [],
                        timeframe: .sevenDays,
                        currencyCode: "USD",
                        distanceUnit: .miles,
                        weekStartDay: .sunday
                    )
                    .frame(height: 300)
                    
                    StatsChartCard(
                        type: .miles,
                        value: "254.3 mi",
                        chartDataPoints: [],
                        timeframe: .sevenDays,
                        currencyCode: "USD",
                        distanceUnit: .miles,
                        weekStartDay: .sunday
                    )
                }
                .padding()
            }
        }
        .modelContainer(container)
    }
}

#Preview {
    StatsChartCardPreviewHelper()
}

