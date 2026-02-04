//
//  WeatherCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI
import WeatherKit
import SwiftData

struct CurrentConditionsCard: View {
    @EnvironmentObject var manager: WeatherManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Link(destination: manager.weatherURL) {
            HStack(spacing: 16) {

                //Left Sie
                // Icon
                Image(systemName: manager.ui?.conditionIcon ?? "")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 45, height: 45)

                VStack(alignment: .leading) {

                    Text(manager.ui?.conditionDescription ?? "--")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.primary)

                    Text(
                        "H: \(manager.ui?.highTemperature ?? "--") L: \(manager.ui?.lowTemperature ?? "--")"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                }

                Spacer()

                //Right Side
                VStack(alignment: .trailing, spacing: 4) {

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if manager.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }

                        Text(manager.ui?.temperature ?? "--°")
                            .font(.title)
                            .bold()

                    }

                    Text(
                        "Feels like \(manager.ui?.apparentTemperature ?? "--°")"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                }
            }
            .padding()
            .background(Color.gray.opacity(colorScheme == .light ? 0.2 : 0.0))
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))
            .cornerRadius(20)

        }
        .buttonStyle(.plain)
//        .overlay(alignment: .bottomTrailing) {
//            if let errorMsg = manager.error {
//                HStack(spacing: 4) {
//                    Image(systemName: "exclamationmark.triangle.fill")
//                    Text(errorMsg)
//                }
//                .font(.caption2)
//                .foregroundStyle(.white)
//                .padding(8)
//                .background(Color.red.opacity(0.8))
//                .cornerRadius(8)
//                .padding(8)
//            }
//        }
    }
}
#Preview("Critical Alerts") {
    let container = PreviewHelper.makeContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
        .onAppear {
            PreviewHelper.configureDashboardPreview(weather: .criticalAll)
        }
}
