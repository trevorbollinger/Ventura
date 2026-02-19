//
//  BackgroundContainerView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI
import CoreLocation
import Combine

struct AppBackground: View {
    let style: BackgroundStyle
    // We do NOT observe LocationTracker here to prevent redraws of the parent.
    // Instead, we internally observe it ONLY if the style requires it.
    // Optional internal parameter for direct passing if needed (keeping API compat if used elsewhere)
    var userLocation: CLLocation? = nil 
    
    var body: some View {
        switch style {
        case .mesh:
            MeshGradientBackground()
        case .darkGradient:
            DarkGradientBackground()
        case .blurredMap:
            // This component will manage its own location observation
            ConfigurableBlurredMap()
        }
    }
}

// A wrapper that captures location ONCE, not on every GPS update.
// Observing LocationTracker here caused the Map+blur background to re-render
// on every GPS callback — extremely GPU-heavy and a major foreground lag source.
private struct ConfigurableBlurredMap: View {
    @State private var capturedLocation: CLLocation? = LocationTracker.shared.currentLocation
    
    var body: some View {
        BlurredMapBackground(userLocation: capturedLocation)
            .onReceive(
                // Only update location when it changes significantly (> 500m)
                LocationTracker.shared.$currentLocation
                    .compactMap { $0 }
                    .filter { [capturedLocation] newLoc in
                        guard let existing = capturedLocation else { return true }
                        return newLoc.distance(from: existing) > 500
                    }
                    .throttle(for: .seconds(60), scheduler: RunLoop.main, latest: true)
            ) { newLocation in
                capturedLocation = newLocation
            }
    }
}

extension View {
    func appBackground(
        style: BackgroundStyle
    ) -> some View {
        self.background {
            AppBackground(style: style)
                .ignoresSafeArea()
        }
    }
}

#Preview("Mesh") {
    Text("Sample Content")
        .font(.largeTitle)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground(style: .mesh)
}

#Preview("Dark Gradient") {
    Text("Sample Content")
        .font(.largeTitle)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground(style: .darkGradient)
}
