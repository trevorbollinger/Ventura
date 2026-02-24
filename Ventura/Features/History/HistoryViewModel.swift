//
//  HistoryViewModel.swift
//  Ventura
//

import SwiftUI
import SwiftData

@MainActor
@Observable 
class HistoryViewModel {
    var sessions: [Session] = []
    var isLoadingMore = false
    var hasMoreData = true
    
    private let limit = 20
    private var offset = 0
    
    func loadInitialData(modelContext: ModelContext) {
        // Reset state
        offset = 0
        hasMoreData = true
        sessions.removeAll()
        
        loadMore(modelContext: modelContext)
    }
    
    func loadMore(modelContext: ModelContext) {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        
        // Use a detached task for background fetching
        let currentOffset = self.offset
        let fetchLimit = self.limit
        let container = modelContext.container
        
        Task.detached {
            let backgroundContext = ModelContext(container)
            
            var descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.endTimestamp != nil },
                sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
            )
            descriptor.fetchOffset = currentOffset
            descriptor.fetchLimit = fetchLimit
            
            do {
                let fetchedSessions = try backgroundContext.fetch(descriptor)
                
                // Extremely important: SwiftData models cannot be safely passed across actor boundaries.
                // We extract the IDs instead.
                let sessionIDs = fetchedSessions.map { $0.id }
                
                await MainActor.run {
                    self.processFetchedIDs(sessionIDs, in: modelContext)
                }
            } catch {
                print("HistoryViewModel: Failed to fetch sessions: \(error)")
                await MainActor.run {
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func processFetchedIDs(_ ids: [UUID], in context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
        )
        
        var newSessions: [Session] = []
        if let fetched = try? context.fetch(descriptor) {
            newSessions = fetched
        }
        
        if newSessions.count < limit {
            hasMoreData = false
        }
        
        self.sessions.append(contentsOf: newSessions)
        self.offset += newSessions.count
        self.isLoadingMore = false
    }
    
    func remove(sessions IDsToRemove: Set<UUID>, in context: ModelContext) {
        let sessionsToDelete = sessions.filter { IDsToRemove.contains($0.id) }
        
        // Remove from local state immediately to trigger UI update
        withAnimation {
            sessions.removeAll { IDsToRemove.contains($0.id) }
        }
        
        // Delete from context
        for session in sessionsToDelete {
            context.delete(session)
        }
        
        try? context.save()
        
        // Adjust offset so pagination stays correct
        offset -= sessionsToDelete.count
        if offset < 0 { offset = 0 }
    }
}
