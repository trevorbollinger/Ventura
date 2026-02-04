import SwiftData
import SwiftUI

struct EarningsComparisonCard: View {
    @Query(sort: \Session.startTimestamp, order: .reverse) private var sessions:
        [Session]

    enum ComparisonPeriod: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"

        var id: String { rawValue }

        var thisLabel: String { "This \(rawValue)" }
        var lastLabel: String { "Last \(rawValue)" }
    }

    @State private var selectedPeriod: ComparisonPeriod = .week

    // Derived Data
    private var earningsData: (current: Decimal, previous: Decimal) {
        let helper = DateRangeHelper.shared

        let currentStart: Date
        let previousInterval: DateInterval

        switch selectedPeriod {
        case .week:
            currentStart = helper.startOfCurrentWeek
            previousInterval = helper.lastWeekInterval
        case .month:
            currentStart = helper.startOfCurrentMonth
            previousInterval = helper.lastMonthInterval
        case .year:
            currentStart = helper.startOfCurrentYear
            previousInterval = helper.lastYearInterval
        }

        let currentEarnings =
            sessions
            .filter { $0.startTimestamp >= currentStart }
            .reduce(0) { $0 + $1.netProfit }

        let previousEarnings =
            sessions
            .filter { previousInterval.contains($0.startTimestamp) }
            .reduce(0) { $0 + $1.netProfit }

        return (currentEarnings, previousEarnings)
    }

    var body: some View {
        let (current, previous) = earningsData
        let maxValue = max(
            Double(truncating: current as NSNumber),
            Double(truncating: previous as NSNumber)
        )
        // Ensure we handle the 0 case to avoid division by zero
        let scaleMax = maxValue > 0 ? maxValue : 1.0

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.green)
                Text("Earnings Comparison")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                Menu {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ComparisonPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPeriod.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }

                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            VStack(spacing: 12) {
                // Current Period Row
                EarningsBarRow(
                    label: selectedPeriod.thisLabel,
                    amount: current,
                    maxValue: scaleMax,
                    color: .green
                )

                // Previous Period Row
                EarningsBarRow(
                    label: selectedPeriod.lastLabel,
                    amount: previous,
                    maxValue: scaleMax,
                    color: .blue
                )
            }
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct EarningsBarRow: View {
    let label: String
    let amount: Decimal
    let maxValue: Double
    let color: Color

    var body: some View {
        let doubleAmount = Double(truncating: amount as NSNumber)
        // Avoid negative width
        let ratio = max(0, doubleAmount / maxValue)

        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(amount.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)

                    // Filled bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(8, geo.size.width * CGFloat(ratio)),
                            height: 8
                        )
                        // Add a glow effect
                        .shadow(
                            color: color.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    EarningsComparisonCard()
        .padding()
        .background(Color.black)
}
