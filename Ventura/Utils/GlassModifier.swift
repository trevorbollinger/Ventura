//
//  GlassModifier.swift
//  Horizon
//
//  Created by Trevor Bollinger on 1/19/26.
//


import SwiftUI

// IMPORTANT: We cannot name our extension method .glassEffect(in:) because
// that shadows Apple's native API (iOS 26+/macOS 16+) and causes infinite recursion.
// Instead, we use .glassModifier(in:) which safely wraps the native API when available.

extension View {
    /// Apply glass effect - uses native glassEffect on iOS 26+/macOS 16+,
    /// falls back to material on older versions.
    @ViewBuilder
    func glassModifier<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            // Use Apple's native glassEffect API
            self.glassEffect(in: shape)
        } else {
            // Fallback to material background
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
