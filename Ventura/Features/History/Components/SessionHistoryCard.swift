//
//  SessionHistoryCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/23/26.
//

import SwiftUI
import SwiftData

struct SessionHistoryCard: View {
    let startTimestamp: Date
    let endTimestamp: Date?
    let duration: String
    let netProfit: Decimal
    let earningsPerHour: Decimal
    let netPerMile: Decimal
    let currencyCode: String
    let totalMiles: Double
    let deliveriesCount: Int
    let settings: UserSettings

    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .title3) private var profitSize: CGFloat = 22
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // HEADER: profit + date + indicator
            HStack(alignment: .center, spacing: 10) {
                // Profit
                Text(netProfit.formatted(.currency(code: currencyCode)))
                    .font(.system(size: profitSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                // Date + times
                VStack(alignment: .trailing, spacing: 2) {
                    Text(startTimestamp.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 4) {
                        Text(startTimestamp.formatted(Date.FormatStyle().hour().minute()))
                        if let end = endTimestamp {
                            Text("–")
                            Text(end.formatted(Date.FormatStyle().hour().minute()))
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
                HistoryStat(label: "Time", value: duration)
                Spacer()
                HistoryStat(label: "Per Hour", value: earningsPerHour.formatted(.currency(code: currencyCode)))
                Spacer()
                HistoryStat(
                    label: settings.distanceUnit == .kilometers ? "Per Km" : "Per Mile",
                    value: settings.displayPerDistance(perMile: NSDecimalNumber(decimal: netPerMile).doubleValue).formatted(.currency(code: currencyCode))
                )
                Spacer()
                HistoryStat(
                    label: settings.distanceUnit == .kilometers ? "Km" : "Miles",
                    value: String(format: "%.1f", settings.displayDistance(miles: totalMiles))
                )
                Spacer()
                HistoryStat(label: "Deliv.", value: "\(deliveriesCount)")
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassModifier(in: RoundedRectangle(cornerRadius: 24))
        .onTapGesture { onTap() }
    }
}

// MARK: - History Stat

private struct HistoryStat: View {
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


#Preview {
    let container = PreviewHelper.makeContainer()
    return HistoryView()
        .modelContainer(container)
}
