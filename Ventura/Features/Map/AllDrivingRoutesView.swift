//
//  AllDrivingRoutesView.swift
//  Ventura
//
//  Created for Ventura Map Tab.
//

import SwiftUI
import MapKit
import SwiftData

struct AllDrivingRoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AllDrivingRoutesViewModel()
    
    // --- State for Map Settings ---
    @State private var mapStyleOption: MapStyleOption = .standard
    
    enum MapStyleOption: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case hybrid = "Hybrid"
        case imagery = "Satellite"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading Routes...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .zIndex(1)
                }
                
                ZStack(alignment: .top) {
                    Map {
                        ForEach(0..<viewModel.routes.count, id: \.self) { index in
                            MapPolyline(coordinates: viewModel.routes[index])
                                .stroke(.blue.opacity(0.6), lineWidth: 3)
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
                    .padding(.bottom, 60) // Extra padding for tab bar
                }
            }
            .navigationTitle("All Routes")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let container = modelContext.container
                viewModel.loadAllRoutes(container: container)
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
    return AllDrivingRoutesView()
        .modelContainer(container)
}
