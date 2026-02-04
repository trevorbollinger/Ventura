//
//  HistoryView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(filter: #Predicate<Session> { $0.endTimestamp != nil },
           sort: \.startTimestamp, order: .reverse)
    private var sessions: [Session]
    
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

                                    
                                    SessionRowContent(session: session, settings: settings)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(for: session)
                                }
                            } else {
                                // Normal mode
                                NavigationLink(destination: SessionSummarySheet(session: session)) {
                                    SessionRowContent(session: session, settings: settings)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSessions)
                    .deleteDisabled(isSelecting)
                }
            }
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
    }
    
    private func deleteSelectedSessions() {
        withAnimation {
            for session in selectedSessions {
                modelContext.delete(session)
            }
            
            // Exit selection mode
            isSelecting = false
            selectedSessionIDs.removeAll()
            
            try? modelContext.save()
        }
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
    
    private func performCombine(_ sessions: [Session]) {
        withAnimation {
            _ = SessionCombiner.combine(sessions, in: modelContext)
            
            // Exit selection mode
            isSelecting = false
            selectedSessionIDs.removeAll()
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sessions[index])
            }
        }
    }
    

}

// Extracted row content for reuse
struct SessionRowContent: View {
    let session: Session
    let settings: UserSettings
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startTimestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.durationString())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.netProfit.formatted(.currency(code: session.currencyCode)))
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Text("\(session.earningsPerHour.formatted(.currency(code: session.currencyCode)))/hr")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(String(format: "%.1f", settings.displayDistance(miles: session.totalMiles))) \(settings.distanceLabel)")
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
