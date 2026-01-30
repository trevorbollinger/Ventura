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
    
    var body: some View {
        ZStack(alignment: .top) {
            Map {
                // Draw the route line
                if !session.route.isEmpty {
                    MapPolyline(coordinates: session.route.map { 
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
                    })
                    .stroke(.blue, lineWidth: 4)
                }
                
                // Start Marker
                if let first = session.route.first {
                    Marker("Start", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude))
                        .tint(.green)
                }
                
                // End Marker
                if let last = session.route.last {
                    Marker("End", systemImage: "flag.checkered", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                        .tint(.red)
                }
            }
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
    let _ = try! ModelContainer(for: Session.self, UserSettings.self, configurations: config)
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
}
