//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import SwiftUI
import SwiftData
import MapKit
import Combine

struct SettingsHomeLocationEditView: View {
    @Bindable var userSettings: UserSettings
    @Environment(\.dismiss) private var dismiss
    
    let icons = ["house.fill", "building.2.fill", "storefront.fill", "briefcase.fill", "map.fill", "pin.fill", "location.fill", "fork.knife"]
    
    // Map State
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var position: MapCameraPosition = .automatic
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion()
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Name Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Location Name")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    TextField("e.g. Home", text: Binding(
                        get: { userSettings.homeName ?? "" },
                        set: { userSettings.homeName = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.headline)
                    .padding()
                    .glassModifier(in: RoundedRectangle(cornerRadius: 20))

                }
                
                
                // Icon Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Icon")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                        ForEach(icons, id: \.self) { icon in
                            let isSelected = userSettings.homeIcon == icon
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
                                    .glassModifier(in: RoundedRectangle(cornerRadius: 200))

                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                
                            }
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                withAnimation(.snappy) {
                                    userSettings.homeIcon = icon
                                }
                            }
                        }
                    }
                }

                
               
//
                
                // Location Map Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Home Location")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 12) {
                        
                        // Search Bar
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
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(14)
                            
                            if !searchResults.isEmpty {
                                Divider()
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
                                .frame(height: 200)
                            }
                        }
                        .background(Color(.systemBackground))
                        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                        
                        ZStack {
                            Map(position: $position, selection: $selectedLocation) {
                                UserAnnotation()
                                
                                if let lat = userSettings.homeLatitude, let lon = userSettings.homeLongitude {
                                    MapCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: userSettings.homeRadius)
                                        .foregroundStyle(.blue.opacity(0.15))
                                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                                    
                                    Marker(userSettings.homeName ?? "Home", systemImage: userSettings.homeIcon ?? "house.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                        .tint(.blue)
                                }
                            }
                            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
                            .onMapCameraChange { context in
                                mapRegion = context.region
                            }
                            .frame(height: 300)
                            
                            // Crosshair
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .opacity(0.5)
                                .allowsHitTesting(false)
                            
                            // Current Location Button
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
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
                                    .padding()
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        
                        // Controls Area
                        VStack(spacing: 16) {
                            
                            // Address Display & Update Button
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    
                                    Text(userSettings.homeAddress ?? "Move map to select location")
                                        .font(.subheadline)
                                        .foregroundStyle(userSettings.homeAddress != nil ? .primary : .secondary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                                
                                Button {
                                    updateHomeLocation()
                                } label: {
                                    Text("Set Home to Center")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            
                            Divider()
                            
                            // Radius Slider
                            if userSettings.homeLatitude != nil {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Radius")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(userSettings.homeRadius)) m")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    
                                    Slider(value: $userSettings.homeRadius, in: 10...150, step: 5) {
                                        Text("Radius")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                
                // Remove Location Button
                if userSettings.homeLatitude != nil {
                    Button(role: .destructive) {
                        withAnimation {
                            userSettings.homeLatitude = nil
                            userSettings.homeLongitude = nil
                            userSettings.homeAddress = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Home Location")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Customize Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if userSettings.homeName == nil {
                userSettings.homeName = "Home"
            }
            if userSettings.homeIcon == nil {
                userSettings.homeIcon = "house.fill"
            }
            
            if let lat = userSettings.homeLatitude, let lon = userSettings.homeLongitude {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            } else {
                position = .userLocation(fallback: .automatic)
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        searchText = ""
        
        withAnimation(.spring()) {
            position = .region(MKCoordinateRegion(
                center: item.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
        
        // Optional: Auto-update when selecting from list? 
        // For now, let's let the user click "Set Home to Center" to confirm.
        // Or we can just trigger it.
        // Let's trigger it for better UX.
        // updateHomeLocation(using: item.placemark.coordinate) // If we want auto-save
        // But for consistency with the map drag, we'll just move the map.
    }
    
    private func updateHomeLocation() {
        let center = mapRegion.center
        userSettings.homeLatitude = center.latitude
        userSettings.homeLongitude = center.longitude
        
        // Reverse geocode
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
        }
    }
}

#Preview {
    let container = PreviewHelper.makeEmptyContainer()
    // We need to fetch the settings object that PreviewHelper created
    let context = container.mainContext
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    
    return NavigationStack {
        SettingsHomeLocationEditView(userSettings: settings)
    }
    .modelContainer(container)
}
