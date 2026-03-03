//
//  DashboardGraphSection.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/27/26.
//

import SwiftUI
import SwiftData

/// A reusable section of bar graphs that displays pre-computed data.
/// Used on both Dashboard and Analytics tabs.
///
/// IMPORTANT: This view receives pre-computed [BarDataPoint] arrays
/// instead of raw [Session] data. The computation is done on a background
/// thread by DashboardGraphViewModel to avoid main-thread SwiftData faulting.
struct DashboardGraphSection: View {
    let earningsPerHourData: [BarDataPoint]
    let hoursWorkedData: [BarDataPoint]
    let netEarningsData: [BarDataPoint]
    let currencyCode: String

    // MARK: - View

    var body: some View {
        VStack(spacing: 14) {
            BarGraphCard(
                title: "$/Hour",
                icon: "dollarsign.circle.fill",
                accentColor: .green,
                data: earningsPerHourData,
                formatStyle: .currency(currencyCode)
            )

            BarGraphCard(
                title: "Hours Worked",
                icon: "clock.fill",
                accentColor: Color("WageColor"),
                data: hoursWorkedData,
                formatStyle: .hours
            )

            BarGraphCard(
                title: "Net Earnings",
                icon: "banknote.fill",
                accentColor: Color("TipsColor"),
                data: netEarningsData,
                formatStyle: .currency(currencyCode)
            )
        }
    }
}

// MARK: - Previews

#Preview("Graph Section") {
    ScrollView {
        DashboardGraphSection(
            earningsPerHourData: [
                BarDataPoint(label: "2/21", value: 22.50),
                BarDataPoint(label: "2/22", value: 18.75),
                BarDataPoint(label: "2/23", value: 31.20),
            ],
            hoursWorkedData: [
                BarDataPoint(label: "2/21", value: 4.5),
                BarDataPoint(label: "2/22", value: 6.2),
                BarDataPoint(label: "2/23", value: 3.0),
            ],
            netEarningsData: [
                BarDataPoint(label: "2/21", value: 85.00),
                BarDataPoint(label: "2/22", value: 102.30),
                BarDataPoint(label: "2/23", value: 67.50),
            ],
            currencyCode: "USD"
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
