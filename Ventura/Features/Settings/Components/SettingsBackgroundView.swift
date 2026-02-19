//
//  SettingsBackgroundView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI
import CoreLocation

struct SettingsBackgroundView: View {
    @Bindable var userSettings: UserSettings
    @ObservedObject private var locationTracker = LocationTracker.shared
    @ObservedObject private var weatherManager = WeatherManager.shared
    
    var currentLocation: CLLocation? {
        locationTracker.currentLocation ?? weatherManager.lastKnownLocation
    }
    
    var body: some View {
        List {
            Section {
                ForEach(BackgroundStyle.allCases) { style in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            userSettings.backgroundStyle = style
                        }
                    } label: {
                        HStack(spacing: 16) {
                            // Preview
                            ZStack {
                                switch style {
                                case .mesh:
                                    MeshGradientBackground()
                                case .darkGradient:
                                    DarkGradientBackground()
                                case .blurredMap:
                                    BlurredMapBackground(userLocation: currentLocation)
                                }
                                
                                // Glass card overlay to show effect
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.clear)
                                    .frame(width: 40, height: 40)
                                    .glassModifier(in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: style.icon)
                                        .foregroundStyle(.blue)
                                    Text(style.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // Checkmark
                            if userSettings.backgroundStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Background Style")
            } footer: {
                Text("Choose a background style that enhances the glass effect throughout the app.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            AppBackground(
                style: userSettings.backgroundStyle,
                userLocation: currentLocation
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Background")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsBackgroundView(
            userSettings: UserSettings()
        )
    }
}
