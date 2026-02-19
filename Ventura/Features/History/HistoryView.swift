//
//  HistoryView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    // PERFORMANCE: Manual fetch to prevent foreground lag
    @State private var sessions: [Session] = []
    
    // Manual load
    private func loadSessions() async {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endTimestamp != nil },
            sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
        )
        do {
            sessions = try modelContext.fetch(descriptor)
        } catch {
            print("HistoryView: Failed to fetch sessions: \(error)")
        }
    }
    
    @Query private var allSettings: [UserSettings]
    private var settings: UserSettings { allSettings.first ?? UserSettings() }
    
    @Environment(\.modelContext) private var modelContext
    
    // Selection state
    @State private var isSelecting = false
    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var showRateConflictSheet = false
    @State private var conflictingFields: [String] = []
    @State private var showDeleteConfirmation = false
    @State private var showCombineConfirmation = false
    
    private var selectedSessions: [Session] {
        sessions.filter { selectedSessionIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView("No History", 
                                           systemImage: "clock.arrow.circlepath", 
                                           description: Text("Completed sessions will appear here."))
                                        .transition(.opacity)

                } else {
                    ForEach(sessions) { session in
                        Group {
                            if isSelecting {
                                // Selection mode
                                HStack(spacing: 12) {
                                    Image(systemName: selectedSessionIDs.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedSessionIDs.contains(session.id) ? .blue : .gray.opacity(0.3))
                                                            .transition(.opacity)

                                    
                                    SessionRowContent(
                                        startTimestamp: session.startTimestamp,
                                        duration: session.durationString(),
                                        netProfit: session.netProfit,
                                        earningsPerHour: session.earningsPerHour,
                                        currencyCode: session.currencyCode,
                                        totalMiles: session.totalMiles,
                                        settings: settings
                                    )
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(for: session)
                                }
                            } else {
                                // Normal mode
                                NavigationLink(destination: SessionSummarySheet(session: session)) {
                                    SessionRowContent(
                                        startTimestamp: session.startTimestamp,
                                        duration: session.durationString(),
                                        netProfit: session.netProfit,
                                        earningsPerHour: session.earningsPerHour,
                                        currencyCode: session.currencyCode,
                                        totalMiles: session.totalMiles,
                                        settings: settings
                                    )
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSessions)
                    .deleteDisabled(isSelecting)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                AppBackground(
                    style: settings.backgroundStyle,
                    userLocation: nil
                )
                .ignoresSafeArea()
            )
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelecting ? "Cancel" : "Select") {
                        if isSelecting {
                            isSelecting = false
                            selectedSessionIDs.removeAll()
                        } else {
                            isSelecting = true
                        }
                    }
                    .opacity(sessions.isEmpty ? 0 : 1)
                    .disabled(sessions.isEmpty)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting && !selectedSessionIDs.isEmpty {
                        HStack(spacing: 8) {
                            // Delete
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .padding(.horizontal, 4)
                            }
                            .tint(.red)
                            .transition(.opacity)
                            
                            // Combine
                            if selectedSessionIDs.count >= 2 {
                                Button {
                                    showCombineConfirmation = true
                                } label: {
                                    Label("Combine", systemImage: "arrow.triangle.merge")
                                        .padding(.horizontal, 4)
                                }
                                .tint(.blue)
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showRateConflictSheet) {
                RateConflictSheet(
                    sessions: selectedSessions,
                    conflictingFields: conflictingFields
                ) { referenceSession in
                    normalizeAndCombine(using: referenceSession)
                }
            }
            .confirmationDialog("Delete Sessions", isPresented: $showDeleteConfirmation) {
                Button("Delete \(selectedSessions.count) Session\(selectedSessions.count == 1 ? "" : "s")", role: .destructive) {
                    deleteSelectedSessions()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete these sessions? This action cannot be undone.")
            }
            .confirmationDialog("Combine Sessions", isPresented: $showCombineConfirmation) {
                Button("Combine \(selectedSessions.count) Sessions") {
                    attemptCombine()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to combine these sessions into a single entry?")
            }
        }
        .task {
            // Load on appear
            await loadSessions()
        }
    }
    
    private func deleteSelectedSessions() {
        // Collect IDs to delete
        let idsToDelete = selectedSessionIDs
        // Find objects to delete (before removing from array)
        let sessionsToDelete = sessions.filter { idsToDelete.contains($0.id) }
        
        withAnimation {
            // Remove from local state immediately to trigger UI update
            sessions.removeAll { idsToDelete.contains($0.id) }
            
            // Exit selection mode
            isSelecting = false
            selectedSessionIDs.removeAll()
        }
        
        // Delete from context
        // Ideally we should do this slightly after asking UI to update, but doing it here is usually fine
        // IF the UI views don't depend on the deleted objects.
        // Now that SessionRowContent uses values, it should be safe.
        for session in sessionsToDelete {
            modelContext.delete(session)
        }
        
        try? modelContext.save()
    }
    
    private func toggleSelection(for session: Session) {
        if selectedSessionIDs.contains(session.id) {
            selectedSessionIDs.remove(session.id)
        } else {
            selectedSessionIDs.insert(session.id)
        }
    }
    
    private func attemptCombine() {
        let selected = selectedSessions
        let validation = SessionCombiner.canCombine(selected)
        
        if validation.canCombine {
            // Rates match, combine directly
            performCombine(selected)
        } else {
            // Show conflict resolution sheet
            conflictingFields = validation.conflictingFields ?? []
            showRateConflictSheet = true
        }
    }
    
    private func normalizeAndCombine(using referenceSession: Session) {
        // Update all selected sessions to match the reference session's rates
        for session in selectedSessions {
            if session.id != referenceSession.id {
                session.adoptRates(from: referenceSession)
            }
        }
        
        // Dismiss sheet
        showRateConflictSheet = false
        
        // Now combine
        performCombine(selectedSessions)
    }
    
    private func performCombine(_ sessionsToCombine: [Session]) {
        withAnimation {
            // Combine returns the new session, identifying those that were removed/merged
            let _ = SessionCombiner.combine(sessionsToCombine, in: modelContext)
            
            // Refresh the list locally to reflect changes
             Task {
                await loadSessions()
            }
            
            // Exit selection mode
            isSelecting = false
            selectedSessionIDs.removeAll()
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        let sessionsToDelete = offsets.map { sessions[$0] }
        
        withAnimation {
            sessions.remove(atOffsets: offsets)
        }
        
        // Delete from context safely
        for session in sessionsToDelete {
            modelContext.delete(session)
        }
    }
    
}

// Extracted row content for reuse
struct SessionRowContent: View {
    let startTimestamp: Date
    let duration: String
    let netProfit: Decimal
    let earningsPerHour: Decimal
    let currencyCode: String
    let totalMiles: Double
    let settings: UserSettings
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(startTimestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(netProfit.formatted(.currency(code: currencyCode)))
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Text("\(earningsPerHour.formatted(.currency(code: currencyCode)))/hr")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(String(format: "%.1f", settings.displayDistance(miles: totalMiles))) \(settings.distanceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}    



#Preview {
    let container = PreviewHelper.makeContainer()
    return HistoryView()
        .modelContainer(container)
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    return HistoryView()
        .modelContainer(container)
}
