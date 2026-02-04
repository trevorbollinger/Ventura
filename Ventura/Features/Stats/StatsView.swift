//
//  StatsView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startTimestamp, order: .reverse) private var allSessions: [Session]
    
    @State private var selectedTimeframe: Timeframe = .sevenDays
    
    let spacing = 13.0
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: spacing) {
                    // Subtitle (Date Range)
                    Text(dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .id("TimeframePicker")
                    .animation(nil, value: selectedTimeframe)
                    .padding(.horizontal)

                    if filteredSessions.isEmpty {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.bar.xaxis",
                            description: Text("No sessions found for this timeframe.")
                        )
                        .padding(.top, 50)
                    } else {
                        // Mixed Grid
                        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                            ForEach(StatType.allCases) { type in
                                if isCompact(type) {
                                    // Half-Width Compact Card
                                    GridRow {
                                        CompactStatCard(
                                            title: type.title,
                                            value: value(for: type),
                                            icon: type.icon,
                                            color: type.color
                                        )
                                        // Empty View for the second column to balance the row?
                                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                                    }
                                } else {
                                    // Full-Width Chart Card
                                    GridRow {
                                        StatsChartCard(
                                            type: type,
                                            value: value(for: type),
                                            sessions: filteredSessions,
                                            timeframe: selectedTimeframe
                                        )
                                        .gridCellColumns(2) // Span both columns
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Analytics")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Computed Properties
    
    func isCompact(_ type: StatType) -> Bool {
        return type == .dollarsPerMile
    }
    
    func value(for type: StatType) -> String {
        switch type {
        case .netProfit:
            return totalNetProfit.formatted(.currency(code: "USD"))
        case .miles:
            return totalMiles.formatted(.number.precision(.fractionLength(1)))
        case .hours:
            return totalHours.formatted(.number.precision(.fractionLength(1)))
        case .deliveries:
            return "\(totalDeliveries)"
        case .hourlyProfit:
            return avgHourlyRate.formatted(.currency(code: "USD"))
        case .dollarsPerMile:
            return avgDollarsPerMile.formatted(.currency(code: "USD"))
        }
    }
    

    var filteredSessions: [Session] {
        let calendar = Calendar.current
        let now = Date()
        
        return allSessions.filter { session in
            guard let end = session.endTimestamp else { return false }
            
            let helper = DateRangeHelper.shared
            
            switch selectedTimeframe {
            case .oneDay:
                return Calendar.current.isDateInToday(end)
            case .sevenDays:
                // "This Week" - Start of current week
                return end >= helper.startOfCurrentWeek
            case .twoWeeks:
                // "2 Weeks" - This week + Last week
                let start = helper.startOfWeeksAgo(1)
                return end >= start
            case .fiveWeeks:
                // "5 Weeks" - This week + Last 4 weeks
                let start = helper.startOfWeeksAgo(4)
                return end >= start
            case .thirteenWeeks:
                let start = helper.startOfWeeksAgo(12)
                return end >= start
            case .fiftyTwoWeeks:
                let start = helper.startOfWeeksAgo(51)
                return end >= start
            case .all:
                return true
            }
        }
    }
    
    var totalNetProfit: Decimal {
        filteredSessions.reduce(0) { $0 + $1.netProfit }
    }
    
    var totalMiles: Double {
        filteredSessions.reduce(0) { $0 + $1.totalMiles }
    }
    
    var totalHours: Decimal {
        filteredSessions.reduce(0) { $0 + $1.durationInHours }
    }
    
    var totalDeliveries: Int {
        filteredSessions.reduce(0) { $0 + $1.deliveriesCount }
    }
    
    var avgHourlyRate: Decimal {
        guard totalHours > 0 else { return 0 }
        return totalNetProfit / totalHours
    }
    
    var avgDollarsPerMile: Decimal {
        guard totalMiles > 0 else { return 0 }
        return totalNetProfit / Decimal(totalMiles)
    }
    
    var dateRangeText: String {
        if filteredSessions.isEmpty {
            return "No Data"
        }
        
        let helper = DateRangeHelper.shared
        let now = Date()
        
        switch selectedTimeframe {
        case .oneDay:
            return now.formatted(date: .abbreviated, time: .omitted)
        case .sevenDays:
            return "This Week"
        case .all:
             if let earliest = filteredSessions.last?.startTimestamp {
                return "Since \(earliest.formatted(date: .abbreviated, time: .omitted))"
            }
            return "All Time"
        default:
             // Get the start date of the filter
             let start: Date
             switch selectedTimeframe {
             case .twoWeeks: start = helper.startOfWeeksAgo(1)
             case .fiveWeeks: start = helper.startOfWeeksAgo(4)
             case .thirteenWeeks: start = helper.startOfWeeksAgo(12)
             case .fiftyTwoWeeks: start = helper.startOfWeeksAgo(51)
             default: start = now
             }
             return helper.formatRange(start, now)
        }
    }
}

// MARK: - Support Types

enum Timeframe: String, CaseIterable, Identifiable {
    case oneDay = "Today"
    case sevenDays = "Week"
    case twoWeeks = "2W"
    case fiveWeeks = "5W"
    case thirteenWeeks = "13W"
    case fiftyTwoWeeks = "52W"
    case all = "All"
    
    var id: String { rawValue }
}

enum StatType: String, CaseIterable, Identifiable {
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

struct CompactStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    return StatsView()
        .modelContainer(container)
}
