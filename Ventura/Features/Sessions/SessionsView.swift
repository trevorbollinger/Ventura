//
//  SessionsView.swift
//  Ventura
//
//  Created for Ventura 2.0 rebuild.
//  This view ONLY displays data from SessionsViewModel.
//  It never touches SwiftData directly for reads.
//

import SwiftUI
import SwiftData

struct SessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @State private var viewModel = SessionsViewModel()
    
    @Query private var allSettings: [UserSettings]
    private var settings: UserSettings { allSettings.first ?? UserSettings() }
    
    // Selection state
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    
    // Dialogs
    @State private var showDeleteConfirmation = false
    @State private var showCombineConfirmation = false
    @State private var showRateConflictSheet = false
    @State private var conflictingFields: [String] = []
    
    // Navigation
    @State private var navigationPath: [Session] = []
    
    private var container: ModelContainer {
        modelContext.container
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.items.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed sessions will appear here.")
                    )
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.items) { item in
                                SessionCard(
                                    item: item,
                                    isSelecting: isSelecting,
                                    isSelected: selectedIDs.contains(item.id),
                                    onTap: {
                                        if isSelecting {
                                            toggleSelection(for: item.id)
                                        } else {
                                            navigateToSession(id: item.id)
                                        }
                                    }
                                )
                            }
                            
                            if viewModel.hasMoreData {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .onAppear {
                                        viewModel.loadMore(
                                            container: container,
                                            settings: settings
                                        )
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
            .scrollContentBackground(.hidden)
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelecting ? "Cancel" : "Select") {
                        if isSelecting {
                            isSelecting = false
                            selectedIDs.removeAll()
                        } else {
                            isSelecting = true
                        }
                    }
                    .opacity(viewModel.items.isEmpty ? 0 : 1)
                    .disabled(viewModel.items.isEmpty)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting && !selectedIDs.isEmpty {
                        HStack(spacing: 8) {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .padding(.horizontal, 4)
                            }
                            .tint(.red)
                            .transition(.opacity)
                            
                            if selectedIDs.count >= 2 {
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
                let sessions = viewModel.fetchSessions(ids: selectedIDs, context: modelContext)
                RateConflictSheet(
                    sessions: sessions,
                    conflictingFields: conflictingFields
                ) { referenceSession in
                    normalizeAndCombine(using: referenceSession)
                }
            }
            .confirmationDialog("Delete Sessions", isPresented: $showDeleteConfirmation) {
                Button("Delete \(selectedIDs.count) Session\(selectedIDs.count == 1 ? "" : "s")", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete these sessions? This action cannot be undone.")
            }
            .confirmationDialog("Combine Sessions", isPresented: $showCombineConfirmation) {
                Button("Combine \(selectedIDs.count) Sessions") {
                    attemptCombine()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to combine these sessions into a single entry?")
            }
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.loadInitialData(
                    container: container,
                    settings: settings
                )
            } else if let lastEnded = sessionManager.lastEndedSession, !viewModel.items.contains(where: { $0.id == lastEnded.id }) {
                viewModel.loadInitialData(
                    container: container,
                    settings: settings
                )
            }
        }
        .onChange(of: sessionManager.lastEndedSession) { _, newSession in
            // When a session ends while we're away from the tab or in the background, this forces a refresh.
            if let ended = newSession, !viewModel.items.contains(where: { $0.id == ended.id }) {
                viewModel.loadInitialData(
                    container: container,
                    settings: settings
                )
            }
        }
    }
    
    // MARK: - Actions (thin wrappers — logic lives in ViewModel)
    
    private func toggleSelection(for id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
    
    private func navigateToSession(id: UUID) {
        // Need to fetch the actual Session for the detail view
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == id }
        )
        if let session = try? modelContext.fetch(descriptor).first {
            navigationPath.append(session)
        }
    }
    
    private func deleteSelected() {
        viewModel.deleteSessions(
            ids: selectedIDs,
            container: container,
            settings: settings
        )
        withAnimation {
            isSelecting = false
            selectedIDs.removeAll()
        }
    }
    
    private func attemptCombine() {
        let result = viewModel.canCombine(ids: selectedIDs, container: container)
        
        if result.canCombine {
            performCombine()
        } else {
            conflictingFields = result.conflictingFields ?? []
            showRateConflictSheet = true
        }
    }
    
    private func normalizeAndCombine(using referenceSession: Session) {
        let sessions = viewModel.fetchSessions(ids: selectedIDs, context: modelContext)
        for session in sessions {
            if session.id != referenceSession.id {
                session.adoptRates(from: referenceSession)
            }
        }
        showRateConflictSheet = false
        performCombine()
    }
    
    private func performCombine() {
        viewModel.combineSessions(
            ids: selectedIDs,
            container: container,
            context: modelContext,
            settings: settings
        )
        withAnimation {
            isSelecting = false
            selectedIDs.removeAll()
        }
    }
}

// MARK: - Previews

#Preview {
    let container = PreviewHelper.makeContainer()
    SessionsView()
        .modelContainer(container)
        .environment(SessionManager())
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    SessionsView()
        .modelContainer(container)
        .environment(SessionManager())
}
