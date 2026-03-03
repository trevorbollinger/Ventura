//
//  AnalyticsView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/27/26.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @State var graphViewModel = DashboardGraphViewModel()

    private var currentSettings: UserSettings {
        sessionManager.cachedSettings ?? UserSettings()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DashboardGraphSection(
                    earningsPerHourData: graphViewModel.earningsPerHourData,
                    hoursWorkedData: graphViewModel.hoursWorkedData,
                    netEarningsData: graphViewModel.netEarningsData,
                    currencyCode: currentSettings.currencyCode
                )
                .padding()
            }
            .navigationTitle("Analytics")
        }
        .task {
            graphViewModel.loadIfNeeded(
                container: modelContext.container,
                currencyCode: currentSettings.currencyCode
            )
        }
        .onChange(of: sessionManager.lastEndedSession) { _, _ in
            graphViewModel.refresh(
                container: modelContext.container,
                currencyCode: currentSettings.currencyCode
            )
        }
    }
}

// MARK: - Previews

#Preview("Analytics") {
    let container = PreviewHelper.makeContainer()
    AnalyticsView(graphViewModel: PreviewHelper.mockDashboardGraphViewModel)
        .modelContainer(container)
        .environment(SessionManager())
}

#Preview("Analytics - Empty") {
    let container = PreviewHelper.makeEmptyContainer()
    AnalyticsView()
        .modelContainer(container)
        .environment(SessionManager())
}
