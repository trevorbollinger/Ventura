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
            Map(position: $position) {
                UserAnnotation()
                
                // Active Session Route
                if let session = activeSession, !session.route.isEmpty {
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
                
                // Home Location
                if let userSettings = settings.first,
                   let lat = userSettings.homeLatitude,
                   let lon = userSettings.homeLongitude {
                    let homeCoord = CLLocationCoordinate2D(
                        latitude: lat,
                        longitude: lon
                    )
                    
                    MapCircle(
                        center: homeCoord,
                        radius: userSettings.homeRadius
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue.opacity(0.3), lineWidth: 2)
                    
                    Marker(
                        userSettings.homeName ?? "Home",
                        systemImage: userSettings.homeIcon ?? "house.fill",
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
}

#Preview {
    let container = PreviewHelper.makeContainer()
    return LiveSessionMapCard()
        .padding()
        .background(Color.black)
        .modelContainer(container)
        .environmentObject(SessionManager())
}
