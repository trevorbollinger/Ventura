//
//  DashboardMapCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/27/26.
//

import SwiftUI
import MapKit

// MARK: - Dedicated Static Map Component
/// A purely static map component. It takes Settings as a parameter.
/// It observes NO timers and has NO state bindings to prevent redraw loops.
struct DashboardMapCard: View, Equatable {
    let settings: UserSettings
    
    var homeCoord: CLLocationCoordinate2D? {
        guard let lat = settings.homeLatitude, let lon = settings.homeLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(.blue)
                Text("Your Zone")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            Map(initialPosition: .userLocation(fallback: .automatic)) {
                UserAnnotation()
                
                if let coord = homeCoord {
                    MapCircle(
                        center: coord,
                        radius: settings.homeRadius
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue.opacity(0.3), lineWidth: 2)
                    
                    Marker(
                        settings.homeName ?? "Home",
                        systemImage: settings.homeIcon ?? "house.fill",
                        coordinate: coord
                    )
                    .tint(.blue)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false) // Disable interaction on dashboard
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
    }
    
    // Prevent redraws unless home location actually changes
    static func == (lhs: DashboardMapCard, rhs: DashboardMapCard) -> Bool {
        return lhs.homeCoord?.latitude == rhs.homeCoord?.latitude &&
               lhs.homeCoord?.longitude == rhs.homeCoord?.longitude &&
               lhs.settings.homeRadius == rhs.settings.homeRadius
    }
}

#Preview("Dashboard Map Card") {
    ZStack {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
        DashboardMapCard(settings: UserSettings())
            .padding()
    }
}
