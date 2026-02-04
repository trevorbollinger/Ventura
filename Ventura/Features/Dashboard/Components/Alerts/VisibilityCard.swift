//
//  VisibilityCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI

struct VisibilityCard: View {
    @EnvironmentObject var manager: WeatherManager
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 34

    var body: some View {
        if manager.ui?.isLowVisibility == true {
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse.byLayer)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOW VISIBILITY")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    
                    Text("Visibility is \(manager.ui?.visibility ?? "--"). Reduce speed and increase following distance.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
            )
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))

        }
    }
}

#Preview("Critical Alerts") {
    PreviewHelper.configureWeatherPreview(with: .criticalAll)
    return DashboardView()
}
