//
//  BarGraphCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/27/26.
//

import SwiftUI
import Charts

// MARK: - Data Model

struct BarDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

enum BarFormatStyle {
    case currency(String)   // currency code e.g. "USD"
    case hours
    case number
    case decimal(Int)       // decimal places

    func format(_ value: Double) -> String {
        switch self {
        case .currency(let code):
            return value.formatted(.currency(code: code))
        case .hours:
            let h = Int(value)
            let m = Int((value - Double(h)) * 60)
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        case .number:
            return "\(Int(value))"
        case .decimal(let places):
            return String(format: "%.\(places)f", value)
        }
    }
}

// MARK: - Bar Graph Card

struct BarGraphCard: View {
    let title: String
    let icon: String
    let accentColor: Color
    let data: [BarDataPoint]
    let formatStyle: BarFormatStyle

    @State private var selectedLabel: String?
    @State private var animateChart = false

    private var average: Double {
        guard !data.isEmpty else { return 0 }
        return data.map(\.value).reduce(0, +) / Double(data.count)
    }

    private var maxValue: Double {
        data.map(\.value).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                // Average badge
                if !data.isEmpty {
                    Text("Average \(formatStyle.format(average))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }

            if data.isEmpty {
                // Empty state
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.bar")
                } description: {
                    Text("Complete sessions to see stats.")
                }
                .frame(height: 140)
            } else {
                // Chart
                Chart {
                    ForEach(data) { point in
                        BarMark(
                            x: .value("Label", point.label),
                            y: .value("Value", animateChart ? point.value : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(selectedLabel == nil || selectedLabel == point.label ? 1.0 : 0.4)
                    }

                    // Average reference line
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .chartYScale(domain: 0...(maxValue * 1.15))
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.caption2.weight(.medium))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatStyle.format(v))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedLabel)
                .frame(height: 140)
                .animation(.spring(duration: 0.6, bounce: 0.25), value: animateChart)

                // Selected bar tooltip
                if let label = selectedLabel, let selected = data.first(where: { $0.label == label }) {
                    HStack {
                        Text(selected.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatStyle.format(selected.value))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accentColor)
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(16)
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.25).delay(0.1)) {
                animateChart = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Bar Graph Card") {
    ScrollView {
        VStack(spacing: 16) {
            BarGraphCard(
                title: "$/Hour",
                icon: "dollarsign.circle.fill",
                accentColor: .green,
                data: [
                    BarDataPoint(label: "Mon", value: 221.50),
                    BarDataPoint(label: "Tue", value: 118.75),
                    BarDataPoint(label: "Wed", value: 81.20),
                    BarDataPoint(label: "Thu", value: 251.00),
                    BarDataPoint(label: "Fri", value: 218.40),
                    BarDataPoint(label: "Sat", value: 315.10),
                    BarDataPoint(label: "Sun", value: 119.80),
                ],
                formatStyle: .currency("USD")
            )

            BarGraphCard(
                title: "Hours Worked",
                icon: "clock.fill",
                accentColor: Color("WageColor"),
                data: [
                    BarDataPoint(label: "Mon", value: 4.5),
                    BarDataPoint(label: "Tue", value: 6.2),
                    BarDataPoint(label: "Wed", value: 3.0),
                    BarDataPoint(label: "Thu", value: 7.8),
                    BarDataPoint(label: "Fri", value: 5.5),
                    BarDataPoint(label: "Sat", value: 8.1),
                    BarDataPoint(label: "Sun", value: 2.3),
                ],
                formatStyle: .hours
            )

            BarGraphCard(
                title: "No Data",
                icon: "chart.bar",
                accentColor: .blue,
                data: [],
                formatStyle: .number
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
