//
//  DriveSessionMap.swift
//  Ventura
//
//  Created by Auto-Agent on 2/4/26.
//

import SwiftUI
import MapKit
import SwiftData

struct DriveSessionMap: View, Equatable {
    @Binding var position: MapCameraPosition
    @Binding var isFollowingUser: Bool
    
    // Data for Equatable check
    let session: Session?
    let routeID: UUID
    let homeLocation: CLLocationCoordinate2D?
    let homeRadius: Double
    let homeName: String
    let homeIcon: String
    
    // We implement specific init to make using it easier
    init(
        position: Binding<MapCameraPosition>,
        isFollowingUser: Binding<Bool>,
        session: Session?,
        routeID: UUID,
        homeLocation: CLLocationCoordinate2D?,
        homeRadius: Double = 0,
        homeName: String = "Home",
        homeIcon: String = "house.fill"
    ) {
        self._position = position
        self._isFollowingUser = isFollowingUser
        self.session = session
        self.routeID = routeID
        self.homeLocation = homeLocation
        self.homeRadius = homeRadius
        self.homeName = homeName
        self.homeIcon = homeIcon
    }
    
    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            // Active Session Route
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
                        lineWidth: 5,
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
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    isFollowingUser = false
                }
        )
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: true
            )
        )
    }
    
    static func == (lhs: DriveSessionMap, rhs: DriveSessionMap) -> Bool {
        // Compare efficient properties to decide if we need to redraw
        
        // Critical: Only check ID. If ID matches, route hasn't changed.
        if lhs.routeID != rhs.routeID {
            return false
        }
        
        if lhs.session?.id != rhs.session?.id {
            return false
        }
        
        // Home settings check (unlikely to change during session but safe to check)
        if lhs.homeLocation?.latitude != rhs.homeLocation?.latitude ||
           lhs.homeLocation?.longitude != rhs.homeLocation?.longitude {
            return false
        }
        
        return true
    }
}
