import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct LiveSessionMapCard: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Query private var settings: [UserSettings]
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var activeSession: Session? {
        sessionManager.activeSession
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(.blue)
                Text("Live Route")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Compact Map View
            FrozenMap(
                session: sessionManager.activeSession,
                routeCount: (activeSession?.route.count ?? 0) + 1,
                homeLocation: homeLocation,
                homeRadius: settings.first?.homeRadius ?? 100,
                homeName: settings.first?.homeName ?? "Home",
                homeIcon: settings.first?.homeIcon ?? "house.fill",
                position: $position
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false)
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            position = .userLocation(fallback: .automatic)
        }
    }
    
    var homeLocation: CLLocationCoordinate2D? {
        guard let userSettings = settings.first,
              let lat = userSettings.homeLatitude,
              let lon = userSettings.homeLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

private struct FrozenMap: View, Equatable {
    let session: Session?
    let routeCount: Int
    let homeLocation: CLLocationCoordinate2D?
    let homeRadius: Double
    let homeName: String
    let homeIcon: String
    @Binding var position: MapCameraPosition
    
    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            
            if let session = session, !session.route.isEmpty {
                MapPolyline(
                    coordinates: session.route.map {
                        CLLocationCoordinate2D(
                            latitude: $0.latitude,
                            longitude: $0.longitude
                        )
                    }
                )
                .stroke(
                    .blue,
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
            
            if let homeCoord = homeLocation {
                MapCircle(
                    center: homeCoord,
                    radius: homeRadius
                )
                .foregroundStyle(.blue.opacity(0.15))
                .stroke(.blue.opacity(0.3), lineWidth: 2)
                
                Marker(
                    homeName,
                    systemImage: homeIcon,
                    coordinate: homeCoord
                )
                .tint(.blue)
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: true
            )
        )
    }
    
    static func == (lhs: FrozenMap, rhs: FrozenMap) -> Bool {
        return lhs.routeCount == rhs.routeCount &&
               lhs.homeLocation?.latitude == rhs.homeLocation?.latitude &&
               lhs.homeLocation?.longitude == rhs.homeLocation?.longitude &&
               lhs.homeRadius == rhs.homeRadius
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    return LiveSessionMapCard()
        .padding()
        .background(Color.black)
        .modelContainer(container)
        .environmentObject(SessionManager())
}
