//
//  PrecipWarningCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI
import Charts

struct PrecipWarningCard: View {
    @EnvironmentObject var manager: WeatherManager
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 34
    @ScaledMetric(relativeTo: .caption2) private var chartFontSize: CGFloat = 8

    var body: some View {
        if manager.ui?.isPrecipitationAlert == true {
            mainContent
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            
            if let intensityData = manager.ui?.precipitationIntensityForecast, !intensityData.isEmpty {
                chartSection(data: intensityData)
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
        )
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: manager.ui?.precipitationIcon ?? "cloud.rain.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.blue.gradient)
                .symbolEffect(.bounce, value: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("PRECIPITATION WARNING")
                    .font(.headline)
                    .foregroundStyle(Color.blue)
                    .fontWeight(.bold)
                
                Text("\(manager.ui?.precipitationChance ?? "--%") chance of \(manager.ui?.precipitationText.lowercased() ?? "loading...")")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
    }

    private func chartSection(data: [PrecipDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Probability", point.intensity)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .chartXAxis {
                // Show only first, middle, and last time markers for clarity
                let timeMarkers = [data.first?.date, data[data.count / 2].date, data.last?.date].compactMap { $0 }
                AxisMarks(values: timeMarkers) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.blue.opacity(0.15))
                    
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)).minute())
                        .font(.system(size: chartFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue.opacity(0.6))
                }
            }
            .frame(height: 100)
        }
        .padding(.horizontal, 12)
    }
}

#Preview("Critical Alerts") {
    let _ = PreviewHelper.configureWeatherPreview(with: .criticalAll)
    return DashboardView()
}

