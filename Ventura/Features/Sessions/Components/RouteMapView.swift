    //
//  RateConflictSheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import MapKit
import SwiftData

struct RouteMapView: View {
    let session: Session
    
    // --- State for Map Settings ---
    @State private var mapStyleOption: MapStyleOption = .standard
    
    enum MapStyleOption: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case hybrid = "Hybrid"
        case imagery = "Satellite"
        
        var id: String { rawValue }
    }
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoadingRoute = true
    
    var body: some View {
        ZStack(alignment: .top) {
            StaticFullRouteMap(routeCoordinates: routeCoordinates)
            .mapStyle(currentMapStyle)
            .padding(.bottom, 15)
            .edgesIgnoringSafeArea(.bottom)
            
            
            // Floating Segmented Picker
            VStack {
                Spacer()
                Picker("Map Style", selection: $mapStyleOption) {
                    ForEach(MapStyleOption.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .id("MapStylePicker")
                .animation(nil, value: mapStyleOption)
                .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                
                .padding()
            }
            .padding(.horizontal, 10)

        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Asynchronously fetch the route to avoid SwiftData deserialization lag on the main thread
            let sessionID = session.id
            let container = session.modelContext?.container
            
            guard let container = container else {
                isLoadingRoute = false
                return
            }
            
            Task.detached {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { $0.id == sessionID }
                )
                
                if let bgSession = try? context.fetch(descriptor).first {
                    // This faults the route on the background thread
                    let points = bgSession.route
                    let coords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    
                    await MainActor.run {
                        self.routeCoordinates = coords
                        self.isLoadingRoute = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingRoute = false
                    }
                }
            }
        }
    }
    
    // --- Computed Properties for Map Configuration ---
    
    private var currentMapStyle: MapStyle {
        switch mapStyleOption {
        case .standard:
            return .standard(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        case .imagery:
            return .imagery(elevation: .realistic)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, UserSettings.self, configurations: config)
    let settings = UserSettings()
    let session = Session(userSettings: settings)
    
    // Add dummy route
    session.route = [
        LocationData(latitude: 37.7749, longitude: -122.4194, timestamp: Date(), speed: 0, altitude: 0),
        LocationData(latitude: 37.7850, longitude: -122.4100, timestamp: Date(), speed: 0, altitude: 0),
        LocationData(latitude: 37.7900, longitude: -122.4050, timestamp: Date(), speed: 0, altitude: 0)
    ]
    
    return NavigationStack {
        RouteMapView(session: session)
    }
    .modelContainer(container)
}

struct StaticFullRouteMap: View, Equatable {
    let routeCoordinates: [CLLocationCoordinate2D]

    static func == (lhs: StaticFullRouteMap, rhs: StaticFullRouteMap) -> Bool {
        return lhs.routeCoordinates.count == rhs.routeCoordinates.count &&
               lhs.routeCoordinates.first?.latitude == rhs.routeCoordinates.first?.latitude
    }

    var body: some View {
        Map {
            // Draw the route line
            if !routeCoordinates.isEmpty {
                MapPolyline(coordinates: routeCoordinates)
                .stroke(.blue, lineWidth: 4)
            }
            
            // Start Marker
            if let first = routeCoordinates.first {
                Marker("Start", systemImage: "flag.fill", coordinate: first)
                    .tint(.green)
            }
            
            // End Marker
            if let last = routeCoordinates.last {
                Marker("End", systemImage: "flag.checkered", coordinate: last)
                    .tint(.red)
            }
        }
    }
}
