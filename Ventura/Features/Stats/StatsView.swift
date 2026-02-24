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
    @Environment(SessionManager.self) private var sessionManager
    @Query private var settings: [UserSettings]
    
    
    let spacing = 13.0
    
    var currentCurrencyCode: String {
        settings.first?.currencyCode ?? "USD"
    }
    
    var currentDistanceUnit: DistanceUnit {
        settings.first?.distanceUnit ?? .miles
    }
    
    // ... (body remains mostly same, need to pass settings to StatsChartCard)
    
    // ...
    
    func value(for type: StatType) -> String {
        let stats = sessionManager.cachedStats
        switch type {
        case .netProfit:
            return stats.netProfit.formatted(.currency(code: currentCurrencyCode))
        case .miles:
            let dist = Measurement(value: stats.totalMiles, unit: UnitLength.miles)
            let converted = dist.converted(to: currentDistanceUnit.unit)
            return converted.value.formatted(.number.precision(.fractionLength(1))) + " " + currentDistanceUnit.title
        case .hours:
            return stats.totalHours.formatted(.number.precision(.fractionLength(1)))
        case .deliveries:
            return "\(stats.deliveries)"
        case .hourlyProfit:
            return stats.hourlyProfit.formatted(.currency(code: currentCurrencyCode))
        case .dollarsPerMile:
            return stats.dollarsPerMile.formatted(.currency(code: currentCurrencyCode))
        }
    }
    
    // ... filtering logic ...
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: spacing) {
                    // Subtitle (Date Range)
                    Text(sessionManager.cachedStats.dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Timeframe Picker
                    @Bindable var sm = sessionManager
                    Picker("Timeframe", selection: $sm.selectedTimeframe) {
                        ForEach(Timeframe.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .id("TimeframePicker")
                    .animation(nil, value: sessionManager.selectedTimeframe)
                    .padding(.horizontal)

                    if sessionManager.cachedStats.dateRangeText == "No Data" {
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
                                            chartDataPoints: sessionManager.cachedStats.chartData[type.id] ?? [],
                                            timeframe: sessionManager.selectedTimeframe,
                                            currencyCode: currentCurrencyCode,
                                            distanceUnit: currentDistanceUnit,
                                            weekStartDay: settings.first?.weekStartDay ?? .sunday
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
            .scrollContentBackground(.hidden)
            .background(
                AppBackground(
                    style: settings.first?.backgroundStyle ?? .mesh,
                    userLocation: nil
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Analytics")
        }
    }
    
    // MARK: - Computed Properties
    
    func isCompact(_ type: StatType) -> Bool {
        return type == .dollarsPerMile
    }
}

// MARK: - Support Types

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
    StatsView()
        .modelContainer(container)
}
