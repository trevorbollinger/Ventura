//
//  HistoryView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    
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
    @State private var navigationPath: [Session] = []
    
    private var selectedSessions: [Session] {
        viewModel.sessions.filter { selectedSessionIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.sessions.isEmpty {
                    ContentUnavailableView("No History",
                                          systemImage: "clock.arrow.circlepath",
                                          description: Text("Completed sessions will appear here."))
                        .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.sessions) { session in
                                SessionHistoryCard(
                                    session: session,
                                    settings: settings,
                                    isSelecting: isSelecting,
                                    isSelected: selectedSessionIDs.contains(session.id),
                                    onTap: {
                                        if isSelecting {
                                            toggleSelection(for: session)
                                        } else {
                                            navigationPath.append(session)
                                        }
                                    }
                                )
                            }
                            
                            if viewModel.hasMoreData {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .onAppear {
                                        viewModel.loadMore(modelContext: modelContext)
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionSummarySheet(session: session)
            }
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
                    .opacity(viewModel.sessions.isEmpty ? 0 : 1)
                    .disabled(viewModel.sessions.isEmpty)
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
        .onAppear {
            if viewModel.sessions.isEmpty {
                viewModel.loadInitialData(modelContext: modelContext)
            }
        }
    }
    
    private func deleteSelectedSessions() {
        viewModel.remove(sessions: selectedSessionIDs, in: modelContext)
        withAnimation {
            isSelecting = false
            selectedSessionIDs.removeAll()
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
    
    private func performCombine(_ sessionsToCombine: [Session]) {
        withAnimation {
            // Combine returns the new session, identifying those that were removed/merged
            let _ = SessionCombiner.combine(sessionsToCombine, in: modelContext)
            
            // Refresh the list locally to reflect changes
            viewModel.loadInitialData(modelContext: modelContext)
            
            // Exit selection mode
            isSelecting = false
            selectedSessionIDs.removeAll()
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
