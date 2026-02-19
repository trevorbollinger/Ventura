//
//  BlurredMapBackground.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct BlurredMapBackground: View {
    var userLocation: CLLocation?
    
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            // Black base for dark mode
            Color.black
            
            // Map with blur
            Map(position: $position)
                .mapStyle(
                    .standard(
                        elevation: .realistic,
                        pointsOfInterest: .excludingAll,
                        showsTraffic: false
                    )
                )
                .blur(radius: 14)
                .opacity(0.65)
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .onAppear {
                    if let location = userLocation {
                        position = .camera(
                            MapCamera(
                                centerCoordinate: location.coordinate,
                                distance: 10000,
                                heading: 0,
                                pitch: 0
                            )
                        )
                    }
                }
                .onChange(of: userLocation) { _, newLocation in
                    if let location = newLocation {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            position = .camera(
                                MapCamera(
                                    centerCoordinate: location.coordinate,
                                    distance: 10000,
                                    heading: 0,
                                    pitch: 0
                                )
                            )
                        }
                    }
                }
            
            // Dark gradient overlay for better text visibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ZStack {
        BlurredMapBackground(
            userLocation: CLLocation(
                latitude: 37.7749,
                longitude: -122.4194
            )
        )
        .ignoresSafeArea()
            
        VStack(spacing: 20) {
            Text("Blurred Map")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Glass Card Example")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Content sits on top of the background with a blur effect.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        }
        .padding()
    }
}
