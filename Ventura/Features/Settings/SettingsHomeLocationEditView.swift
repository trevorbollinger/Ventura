//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import SwiftUI
import SwiftData
import MapKit

struct SettingsHomeLocationEditView: View {
    @Bindable var userSettings: UserSettings
    @Environment(\.dismiss) private var dismiss
    
    let icons = ["house.fill", "building.2.fill", "storefront.fill", "briefcase.fill", "map.fill", "pin.fill", "location.fill", "fork.knife"]
    
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
                    
                    VStack(spacing: 0) {
                        // Map Preview
                        NavigationLink {
                            LocationPickerView(userSettings: userSettings)
                        } label: {
                            ZStack {
                                if let lat = userSettings.homeLatitude, let lon = userSettings.homeLongitude {
                                    Map(position: .constant(.region(MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                    )))) {
                                        // Radius Circle
                                        MapCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: userSettings.homeRadius)
                                            .foregroundStyle(.blue.opacity(0.15))
                                            .stroke(.blue.opacity(0.3), lineWidth: 2)
                                        
                                        // Marker uses current settings
                                        Marker(userSettings.homeName ?? "Home", systemImage: userSettings.homeIcon ?? "house.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                            .tint(.blue)
                                    }
                                    .disabled(true)
                                } else {
                                    ContentUnavailableView("No Location Set", systemImage: "mappin.slash")
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color(.secondarySystemBackground))
                                }
                                
                                // Interactable overlay for tapping
                                Color.black.opacity(0.001)
                            }
                            .frame(height: 200)
                            .clipped()
                        }
                        .buttonStyle(.plain)
                        
                        // Controls Area
                        VStack(spacing: 16) {
                            // Address Link
                            NavigationLink {
                                LocationPickerView(userSettings: userSettings)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    
                                    Text(userSettings.homeAddress ?? "Tap to select a location")
                                        .font(.subheadline)
                                        .foregroundStyle(userSettings.homeAddress != nil ? .primary : .secondary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            
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
                    }
                    .background(Color(.systemBackground))
                    .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                    .cornerRadius(20)
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
