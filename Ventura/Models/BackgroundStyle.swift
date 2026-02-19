//
//  BackgroundStyle.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case mesh = "mesh"
    case darkGradient = "darkGradient"
    case blurredMap = "blurredMap"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mesh:
            return "Mesh Gradient"
        case .darkGradient:
            return "Dark Gradient"
        case .blurredMap:
            return "Blurred Map"
        }
    }
    
    var icon: String {
        switch self {
        case .mesh:
            return "circle.hexagongrid.fill"
        case .darkGradient:
            return "rectangle.fill.on.rectangle.fill"
        case .blurredMap:
            return "map.fill"
        }
    }
    
    var description: String {
        switch self {
        case .mesh:
            return "Animated colored blobs with soft blur"
        case .darkGradient:
            return "Subtle gradient from midnight to deep grey"
        case .blurredMap:
            return "Live blurred map based on your location"
        }
    }
}
