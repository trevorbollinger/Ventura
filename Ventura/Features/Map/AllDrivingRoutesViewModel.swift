//
//  AllDrivingRoutesViewModel.swift
//  Ventura
//
//  Created for Ventura Map Tab.
//  Golden Rule: The View never calculates.
//  All fetching and formatting lives here.
//

import SwiftUI
import SwiftData
import MapKit

@MainActor
@Observable
class AllDrivingRoutesViewModel {
    
    // Published display state
    var routes: [[CLLocationCoordinate2D]] = []
    var isLoading = false
    
    // Initial fetch indicator to ensure we only load once if needed
    private var hasLoaded = false
    
    func loadAllRoutes(container: ModelContainer) {
        guard !isLoading && !hasLoaded else { return }
        isLoading = true
        
        Task.detached {
            let bgContext = ModelContext(container)
            
            // Fetch all sessions that have a route
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.endTimestamp != nil },
                sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
            )
            
            do {
                let sessions = try bgContext.fetch(descriptor)
                
                // Map to [[CLLocationCoordinate2D]] on the background thread
                var allRoutes: [[CLLocationCoordinate2D]] = []
                for session in sessions {
                    let points = session.route
                    if !points.isEmpty {
                        let coords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                        allRoutes.append(coords)
                    }
                }
                
                let finalRoutes = allRoutes
                await MainActor.run {
                    self.routes = finalRoutes
                    self.isLoading = false
                    self.hasLoaded = true
                }
            } catch {
                print("AllDrivingRoutesViewModel: Failed to fetch sessions: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
