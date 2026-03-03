//
//  SessionCard.swift
//  Ventura
//
//  Created for Ventura 2.0 rebuild.
//  Displays a pre-formatted SessionSummaryItem. Zero calculations.
//

import SwiftUI

struct SessionCard: View {
    let item: SessionSummaryItem
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .title3) private var profitSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // HEADER: profit + date + indicator
            HStack(alignment: .center, spacing: 10) {
                // Profit
                Text(item.profit)
                    .font(.system(size: profitSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: item.profitIsNegative ? [.red, .orange] : [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                // Date + times
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.date)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 4) {
                        Text(item.startTime)
                        if let end = item.endTime {
                            Text("–")
                            Text(end)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                // Chevron / selection indicator
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.4))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()
                .opacity(0.5)

            // BODY: stats
            HStack(alignment: .top, spacing: 0) {
                Spacer()
                SessionStat(label: "Time", value: item.duration)
                Spacer()
                SessionStat(label: "Per Hour", value: item.perHour)
                Spacer()
                SessionStat(label: item.perDistanceLabel, value: item.perDistance)
                Spacer()
                SessionStat(label: item.distanceLabel, value: item.distance)
                Spacer()
                SessionStat(label: "Deliv.", value: item.deliveries)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassModifier(in: RoundedRectangle(cornerRadius: 24))
        .onTapGesture { onTap() }
    }
}

// MARK: - Stat Cell

private struct SessionStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Session Card") {
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        
        SessionCard(
            item: SessionSummaryItem(
                id: UUID(),
                profit: "$45.00",
                profitIsNegative: false,
                date: "Sun Feb 23",
                startTime: "12:00 PM",
                endTime: "2:00 PM",
                duration: "2h 0m",
                perHour: "$22.50/hr",
                perDistance: "$3.00",
                perDistanceLabel: "Per Mile",
                distance: "15.0",
                distanceLabel: "Miles",
                deliveries: "4"
            ),
            isSelecting: false,
            isSelected: false,
            onTap: {}
        )
        .padding()
    }
}

#Preview("Session Card - Selecting") {
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        
        SessionCard(
            item: SessionSummaryItem(
                id: UUID(),
                profit: "-$5.00",
                profitIsNegative: true,
                date: "Sun Feb 23",
                startTime: "12:00 PM",
                endTime: "2:00 PM",
                duration: "2h 0m",
                perHour: "-$2.50/hr",
                perDistance: "-$0.33",
                perDistanceLabel: "Per Mile",
                distance: "15.0",
                distanceLabel: "Miles",
                deliveries: "4"
            ),
            isSelecting: true,
            isSelected: true,
            onTap: {}
        )
        .padding()
    }
}
