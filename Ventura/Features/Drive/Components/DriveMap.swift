import SwiftUI
import MapKit

/// A highly-optimized, decoupled Map exclusively for active tracking.
/// We pass down pure value types instead of complex Observable references to prevent
/// iOS 17 `@Observable` loops from invalidating the entire View Tree on 1Hz ticks.
struct DriveMap: View, Equatable {
    let route: [LocationData]
    let cameraResetTrigger: Int
    @Binding var isFollowingUser: Bool
    
    // Home Settings
    let homeLocation: CLLocationCoordinate2D?
    let homeRadius: Double
    let homeName: String
    let homeIcon: String
    
    // MapScope for external control placement
    let scope: Namespace.ID
    
    // Dynamic insets so MapKit centers on the visible area, not the full screen
    let topInset: CGFloat
    let bottomInset: CGFloat
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    init(
        route: [LocationData],
        cameraResetTrigger: Int,
        isFollowingUser: Binding<Bool>,
        homeLocation: CLLocationCoordinate2D?,
        homeRadius: Double,
        homeName: String,
        homeIcon: String,
        scope: Namespace.ID,
        topInset: CGFloat = 0,
        bottomInset: CGFloat = 0
    ) {
        self.route = route
        self.cameraResetTrigger = cameraResetTrigger
        self._isFollowingUser = isFollowingUser
        self.homeLocation = homeLocation
        self.homeRadius = homeRadius
        self.homeName = homeName
        self.homeIcon = homeIcon
        self.scope = scope
        self.topInset = topInset
        self.bottomInset = bottomInset
    }
    
    var body: some View {
        Map(position: $position, scope: scope) {
            // Default blue pulsing dot for user location
            UserAnnotation()
            
            // Re-instated: The Polyline.
            // Because we decoupled this from SwiftData faulting and the 1Hz Dashboard clock,
            // this array is now just pure RAM LocationData and will not throttle the main thread.
            if !route.isEmpty {
                MapPolyline(coordinates: route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            
            // Home Radius overlay
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
        // Hide built-in map controls — we place them externally via MapScope
        .mapControls {}
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        // Tell MapKit about overlay areas so it centers on the visible portion
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: topInset - 50)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: bottomInset + 60)
        }
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                isFollowingUser = false
            }
        )
        .onChange(of: cameraResetTrigger) { _, _ in
            withAnimation {
                position = .userLocation(fallback: .automatic)
            }
        }
    }
    
    // Prevent view tree reconstruction unless absolute necessities change
    static func == (lhs: DriveMap, rhs: DriveMap) -> Bool {
        return lhs.route.count == rhs.route.count &&
               lhs.cameraResetTrigger == rhs.cameraResetTrigger &&
               lhs.homeLocation?.latitude == rhs.homeLocation?.latitude &&
               lhs.homeLocation?.longitude == rhs.homeLocation?.longitude &&
               lhs.topInset == rhs.topInset &&
               lhs.bottomInset == rhs.bottomInset
    }
}

// MARK: - Previews

#Preview("Drive Map") {
    @Previewable @Namespace var mapScope
    DriveMap(
        route: PreviewHelper.mockRoute,
        cameraResetTrigger: 0,
        isFollowingUser: .constant(true),
        homeLocation: CLLocationCoordinate2D(latitude: 41.256, longitude: -95.941),
        homeRadius: 150,
        homeName: "Home",
        homeIcon: "house.fill",
        scope: mapScope
    )
    .mapScope(mapScope)
}

#Preview("Drive Map – No Home") {
    @Previewable @Namespace var mapScope
    DriveMap(
        route: PreviewHelper.mockRoute,
        cameraResetTrigger: 0,
        isFollowingUser: .constant(true),
        homeLocation: nil,
        homeRadius: 0,
        homeName: "Home",
        homeIcon: "house.fill",
        scope: mapScope
    )
    .mapScope(mapScope)
}
