//
//  DashboardGraphViewModel.swift
//  Ventura
//
//  Background view model that pre-computes graph data for the Dashboard
//  and Analytics tabs. Fetches only the 7 most recent completed sessions
//  on a background thread — never touches session.route.
//

import Foundation
import SwiftData

@MainActor
@Observable
class DashboardGraphViewModel {
    var earningsPerHourData: [BarDataPoint] = []
    var hoursWorkedData: [BarDataPoint] = []
    var netEarningsData: [BarDataPoint] = []
    var isLoading = false

    @ObservationIgnored
    private var hasLoaded = false
    
    init(
        earningsPerHourData: [BarDataPoint] = [],
        hoursWorkedData: [BarDataPoint] = [],
        netEarningsData: [BarDataPoint] = []
    ) {
        self.earningsPerHourData = earningsPerHourData
        self.hoursWorkedData = hoursWorkedData
        self.netEarningsData = netEarningsData
        // We cannot set hasLoaded synchronously if it's not isolated or if we need to access MainActor properties,
        // but since hasLoaded is @ObservationIgnored and we are just initializing, it's fine.
        // However, setting properties on a MainActor class from a nonisolated init requires caution. 
        // In Swift 6, we should just let the default empty arrays be and only set them if not empty.
        
        // Actually, since this is a @MainActor class, a nonisolated init can only initialize 
        // stored properties if they are preconcurrency or if we do it carefully.
        // A better approach for Swift 6 is to use @MainActor on the init if we want to set properties, 
        // and have Views call it from a @MainActor context. 
        // Let's keep it @MainActor (which it gets from the class) and fix the View calls instead.
    
        if !earningsPerHourData.isEmpty {
            self.hasLoaded = true
        }
    }
    


    /// Called from `.task {}` — only runs once per view lifetime.
    func loadIfNeeded(container: ModelContainer, currencyCode: String) {
        guard !hasLoaded else { return }
        hasLoaded = true
        load(container: container, currencyCode: currencyCode)
    }

    /// Force refresh (e.g. after a session ends).
    func refresh(container: ModelContainer, currencyCode: String) {
        load(container: container, currencyCode: currencyCode)
    }

    private func load(container: ModelContainer, currencyCode: String) {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false

            var descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.endTimestamp != nil },
                sortBy: [SortDescriptor(\Session.startTimestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 7

            let sessions = (try? context.fetch(descriptor)) ?? []

            // Pre-compute on the background thread
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"

            // Reverse so the chart reads left-to-right chronologically
            let chronological = sessions.reversed()

            var earningsBuilder: [BarDataPoint] = []
            var hoursBuilder: [BarDataPoint] = []
            var netsBuilder: [BarDataPoint] = []

            for session in chronological {
                let label = formatter.string(from: session.startTimestamp)
                earningsBuilder.append(BarDataPoint(
                    label: label,
                    value: NSDecimalNumber(decimal: session.earningsPerHour).doubleValue
                ))
                hoursBuilder.append(BarDataPoint(
                    label: label,
                    value: NSDecimalNumber(decimal: session.durationInHours).doubleValue
                ))
                netsBuilder.append(BarDataPoint(
                    label: label,
                    value: NSDecimalNumber(decimal: session.netProfit).doubleValue
                ))
            }

            // Capture the built arrays locally to pass to the MainActor safely
            let finalEarnings = earningsBuilder
            let finalHours = hoursBuilder
            let finalNets = netsBuilder

            await MainActor.run {
                self.earningsPerHourData = finalEarnings
                self.hoursWorkedData = finalHours
                self.netEarningsData = finalNets
                self.isLoading = false
            }
        }
    }
}
