//
//  WindCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI

struct WindCard: View {
    @EnvironmentObject var manager: WeatherManager
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 34

    var body: some View {
        if manager.ui?.isHighWind == true {
            HStack(spacing: 16) {
                Image(systemName: "wind")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("HIGH WIND WARNING")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                    
                    Text("Gusts up to \(manager.ui?.windGust ?? "--").")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
            )
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))

        }
    }
}
#Preview("Critical Alerts") {
    PreviewHelper.configureWeatherPreview(with: .criticalAll)
    return DashboardView()
}
