//
//  SessionsViewModel.swift
//  Ventura
//
//  Created for Ventura 2.0 rebuild.
//  Golden Rule: The View never calculates.
//  All formatting, fetching, and mutation lives here.
//

import SwiftUI
import SwiftData

// MARK: - Display Struct (Plain value type — safe, lightweight, no SwiftData)

struct SessionSummaryItem: Identifiable, Hashable {
    let id: UUID
    let profit: String
    let profitIsNegative: Bool
    let date: String            // e.g. "Sun Feb 23"
    let startTime: String       // e.g. "2:30 PM"
    let endTime: String?        // e.g. "5:45 PM"
    let duration: String        // e.g. "3h 15m"
    let perHour: String         // e.g. "$12.50"
    let perDistance: String      // e.g. "$0.85"
    let perDistanceLabel: String // e.g. "Per Mile" or "Per Km"
    let distance: String         // e.g. "42.3"
    let distanceLabel: String    // e.g. "Miles" or "Km"
    let deliveries: String       // e.g. "7"
}

// MARK: - ViewModel

@MainActor
@Observable
class SessionsViewModel {
    
    // Published display state
    var items: [SessionSummaryItem] = []
    var isLoading = false
    var hasMoreData = true
    
    // Internal
    private let pageSize = 20
    private var currentOffset = 0
    private var loadedSessionIDs: [UUID] = []  // Tracks ordering for delete/combine ops
    
    // MARK: - Load
    
    func loadInitialData(container: ModelContainer, settings: UserSettings) {
        currentOffset = 0
        hasMoreData = true
        loadedSessionIDs = []
        items = []
        
        loadMore(container: container, settings: settings)
    }
    
    func loadMore(container: ModelContainer, settings: UserSettings) {
        guard !isLoading && hasMoreData else { return }
        isLoading = true
        
        let offset = currentOffset
        let limit = pageSize
        
        Task.detached {
            let bgContext = ModelContext(container)
            
            var descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.endTimestamp != nil },
                sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            do {
                let sessions = try bgContext.fetch(descriptor)
                
                // Map to display structs ON the background thread (golden rule)
                let newItems = sessions.map { session in
                    Self.mapToSummary(session: session, settings: settings)
                }
                let ids = sessions.map { $0.id }
                let fetchedCount = sessions.count
                let batchLimit = limit
                
                await MainActor.run {
                    self.items.append(contentsOf: newItems)
                    self.loadedSessionIDs.append(contentsOf: ids)
                    self.currentOffset += fetchedCount
                    self.hasMoreData = fetchedCount >= batchLimit
                    self.isLoading = false
                }
            } catch {
                print("SessionsViewModel: Failed to fetch sessions: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteSessions(ids: Set<UUID>, container: ModelContainer, settings: UserSettings) {
        // Optimistic UI removal
        withAnimation {
            items.removeAll { ids.contains($0.id) }
            loadedSessionIDs.removeAll { ids.contains($0) }
        }
        currentOffset -= ids.count
        if currentOffset < 0 { currentOffset = 0 }
        
        // Background delete
        Task.detached {
            let bgContext = ModelContext(container)
            let idsArray = Array(ids)
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { idsArray.contains($0.id) }
            )
            
            do {
                let sessions = try bgContext.fetch(descriptor)
                for session in sessions {
                    bgContext.delete(session)
                }
                try bgContext.save()
            } catch {
                print("SessionsViewModel: Failed to delete sessions: \(error)")
            }
        }
    }
    
    // MARK: - Combine
    
    /// Check if selected sessions can be combined (rates match)
    func canCombine(ids: Set<UUID>, container: ModelContainer) -> (canCombine: Bool, conflictingFields: [String]?) {
        // This runs on main but is cheap — just fetches and compares rate structs
        let context = ModelContext(container)
        let idsArray = Array(ids)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { idsArray.contains($0.id) }
        )
        
        guard let sessions = try? context.fetch(descriptor), sessions.count >= 2 else {
            return (false, nil)
        }
        
        return SessionCombiner.canCombine(sessions)
    }
    
    /// Get Session objects for the RateConflictSheet (needs real SwiftData objects)
    func fetchSessions(ids: Set<UUID>, context: ModelContext) -> [Session] {
        let idsArray = Array(ids)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { idsArray.contains($0.id) }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Combine sessions and refresh the list
    func combineSessions(ids: Set<UUID>, container: ModelContainer, context: ModelContext, settings: UserSettings) {
        let idsArray = Array(ids)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { idsArray.contains($0.id) }
        )
        
        guard let sessions = try? context.fetch(descriptor), sessions.count >= 2 else { return }
        
        let _ = SessionCombiner.combine(sessions, in: context)
        try? context.save()
        
        // Full reload to get correct ordering
        loadInitialData(container: container, settings: settings)
    }
    
    // MARK: - Mapping (Pure function — runs on any thread)
    
    nonisolated private static func mapToSummary(session: Session, settings: UserSettings) -> SessionSummaryItem {
        let currencyCode = session.currencyCode
        
        // Profit
        let netProfit = session.netProfit
        let profitStr = netProfit.formatted(.currency(code: currencyCode))
        
        // Date: "Sun Feb 23"
        let dateStr = session.startTimestamp.formatted(
            Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        )
        
        // Times
        let startTimeStr = session.startTimestamp.formatted(
            Date.FormatStyle().hour().minute()
        )
        let endTimeStr = session.endTimestamp?.formatted(
            Date.FormatStyle().hour().minute()
        )
        
        // Duration
        let durationStr = session.durationString()
        
        // Per Hour
        let perHourStr = session.earningsPerHour.formatted(.currency(code: currencyCode))
        
        // Distance (converted for display)
        let displayDist = settings.displayDistance(miles: session.totalMiles)
        let distStr = String(format: "%.1f", displayDist)
        let distLabel = settings.distanceUnit == .kilometers ? "Km" : "Miles"
        
        // Per Distance (converted for display)
        let netPerMileDouble = NSDecimalNumber(decimal: session.netPerMile).doubleValue
        let displayPerDist = settings.displayPerDistance(perMile: netPerMileDouble)
        let perDistStr = displayPerDist.formatted(.currency(code: currencyCode))
        let perDistLabel = settings.distanceUnit == .kilometers ? "Per Km" : "Per Mile"
        
        // Deliveries
        let delivStr = "\(session.deliveriesCount)"
        
        return SessionSummaryItem(
            id: session.id,
            profit: profitStr,
            profitIsNegative: netProfit < 0,
            date: dateStr,
            startTime: startTimeStr,
            endTime: endTimeStr,
            duration: durationStr,
            perHour: perHourStr,
            perDistance: perDistStr,
            perDistanceLabel: perDistLabel,
            distance: distStr,
            distanceLabel: distLabel,
            deliveries: delivStr
        )
    }
}
