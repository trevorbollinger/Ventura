//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import SwiftUI
import MapKit
import SwiftData
import Combine

struct LocationPickerView: View {
    @Bindable var userSettings: UserSettings
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion()
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss
    
    // Layout Constants
    private let mapTopPadding: CGFloat = 00
    private let mapBottomPadding: CGFloat = 115
    
    private var crosshairOffset: CGFloat {
        (mapTopPadding - mapBottomPadding) / 2
    }
    
    // Debounce search
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            // MARK: - Map Layer
            Map(position: $position, selection: $selectedLocation) {
                UserAnnotation()
                
                if let lat = userSettings.homeLatitude, let lon = userSettings.homeLongitude {
                    Marker(userSettings.homeName ?? "Home", systemImage: userSettings.homeIcon ?? "house.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(.blue)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
            .onMapCameraChange { context in
                mapRegion = context.region
            }
            .safeAreaPadding(.top, mapTopPadding)
            .safeAreaPadding(.bottom, mapBottomPadding)
            .safeAreaPadding(.horizontal, 14)
            
            // MARK: - Crosshair Layer
            Image(systemName: "plus")
                .font(.title)
                .foregroundStyle(.primary)
                .opacity(0.5)
                .allowsHitTesting(false)
                .offset(y: crosshairOffset)
            
            VStack {

                Spacer()
                // MARK: - BUTTONS

                // Bottom Actions
                HStack(alignment: .bottom) {
                    
                    
                    
                    // Set Home Button
                    Button {
                        saveManualLocation()
                    } label: {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Set Home Location")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassModifier(in: Capsule())
                    }

                    // Current Location Button
                    Button {
                        withAnimation {
                            position = .userLocation(fallback: .automatic)
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .padding(12)
                            .glassModifier(in: Circle())
                    }
                }
                .padding(.horizontal, 22)
                
                // MARK: SEARCH BAR
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search for an address...", text: $searchText)
                            .textFieldStyle(.plain)
                            .onChange(of: searchText) { _, newValue in
                                debounceSearch(newValue)
                            }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .glassModifier(in: RoundedRectangle(cornerRadius: 200))
                    .padding(.horizontal, 22)

                    if !searchResults.isEmpty {
                        List(searchResults, id: \.self) { item in
                            Button {
                                selectLocation(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown Location")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .frame(maxHeight: 250)
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .navigationTitle("Pick Home Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let lat = userSettings.homeLatitude, let lon = userSettings.homeLongitude {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
    
    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if Task.isCancelled { return }
            
            isSearching = true
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                await MainActor.run {
                    self.searchResults = response.mapItems
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        searchResults = []
        searchText = "" // Clear search and results
        
        withAnimation(.spring()) {
            position = .region(MKCoordinateRegion(
                center: item.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private func saveManualLocation() {
        let center = mapRegion.center
        userSettings.homeLatitude = center.latitude
        userSettings.homeLongitude = center.longitude
        
        // Reverse geocode to get an address string for display
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let address = [
                    placemark.subThoroughfare,
                    placemark.thoroughfare,
                    placemark.locality
                ].compactMap { $0 }.joined(separator: " ")
                
                userSettings.homeAddress = address.isEmpty ? "Custom Location" : address
            } else {
                userSettings.homeAddress = "Custom Location"
            }
            dismiss()
        }
    }
}

#Preview {
    let container = PreviewHelper.makeEmptyContainer()
    let context = container.mainContext
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    
    return NavigationStack {
        LocationPickerView(userSettings: settings)
            .modelContainer(container)
    }
}
