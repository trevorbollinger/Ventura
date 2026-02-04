//
//  TemperatureHealthCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI

struct ExtremeTempCard: View {
    @EnvironmentObject var manager: WeatherManager
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 34

    var body: some View {
        let isCold = manager.ui?.extremeColdAlert ?? false
        let isHeat = manager.ui?.extremeHeatAlert ?? false

        if isCold || isHeat {
            let color = isCold ? Color.cyan : Color.red
            let icon = isCold ? "snowflake" : "flame.fill"
            let title = isCold ? "EXTREME COLD" : "EXTREME HEAT"
            let message =
                isCold
                ? "Battery strain likely. Keep engine warm."
                : "Overheating risk. Monitor temperature gauge."

            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(color)
                        .fontWeight(.bold)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.5), lineWidth: 2)
            )
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))

        }
    }
}

#Preview("Critical Alerts") {
    PreviewHelper.configureWeatherPreview(with: .criticalAll)
    return DashboardView()
}
