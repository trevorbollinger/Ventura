//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SessionInfoLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // Use the shared SessionActivityAttributes
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedView(region: .leading, context: context)
                }
                //
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedView(region: .trailing, context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(region: .center, context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedView(region: .bottom, context: context)
                }

            } compactLeading: {
                CompactView(region: .leading, context: context)
            } compactTrailing: {
                CompactView(region: .trailing, context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen / Banner

struct SessionActivityView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            LiveActivityHeader(
                title: "Tracking Session",
                startTime: context.attributes.startTime
            )
            Divider()
            LiveActivityProfitHero(profit: context.state.netProfit)
            LiveActivityStatsRow(state: context.state)
        }
        .padding(12)
    }
}

// MARK: - Expanded

struct ExpandedView: View {
    @ScaledMetric(relativeTo: .caption) private var headerSize: CGFloat = 12

    enum Region {
        case leading, trailing, center, bottom
    }

    let region: Region
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        switch region {
        case .leading:

            Text(
                "Tracking"
            )
            .monospacedDigit()
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .padding(.leading, 10)
//            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: headerSize, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            
        case .trailing:
            HStack {
                Spacer()
                Text(
                    timerInterval: context.attributes
                        .startTime...Date.distantFuture,
                    countsDown: false
                )
                .monospacedDigit()
//                .padding(.trailing, 8)
                .lineLimit(nil)
                .multilineTextAlignment(.trailing)
//                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(.system(size: headerSize, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                Spacer()

            }
            
        case .center:
            LiveActivityProfitHero(profit: context.state.netProfit)

        case .bottom:
            VStack {
                Spacer()
                LiveActivityStatsRow(state: context.state)

            }
        }
    }
}

// MARK: - Shared Components

struct LiveActivityHeader: View {
    let title: String
    let startTime: Date
    @ScaledMetric(relativeTo: .caption) private var headerSize: CGFloat = 12

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(
                timerInterval: startTime...Date.distantFuture,
                countsDown: false
            )
            .monospacedDigit()
        }
        .padding(.leading, 2)
        .font(.system(size: headerSize, weight: .bold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
    }
}

struct LiveActivityProfitHero: View {
    let profit: Double
    @ScaledMetric(relativeTo: .largeTitle) private var profitSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            Text(profit, format: .currency(code: "USD"))
                .font(
                    .system(size: profitSize, weight: .black, design: .rounded)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())
                .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

struct LiveActivityStatsRow: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top) {
            Spacer()
            LiveActivityStatItem(
                icon: "car.fill",
                color: Color("MileageColor"),
                label: "MILES",
                value: String(format: "%.1f", state.totalMiles)
            )
            Spacer()
            LiveActivityStatItem(
                icon: "briefcase.fill",
                color: .blue,
                label: "DELIV.",
                value: "\(state.deliveryCount)"
            )
            Spacer()
            LiveActivityStatItem(
                icon: "hourglass",
                color: Color("TipsColor"),
                label: "/ HOUR",
                value: state.netHourlyProfit.formatted(.currency(code: "USD"))
            )
            Spacer()
            LiveActivityStatItem(
                icon: "road.lanes",
                color: Color("FuelColor"),
                label: "/ MILE",
                value: state.netPerMile.formatted(.currency(code: "USD"))
            )
            Spacer()
        }
    }
}

struct LiveActivityStatItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .subheadline) private var statValueSize: CGFloat =
        15
    @ScaledMetric(relativeTo: .caption2) private var statLabelSize: CGFloat = 9

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(
                    .system(
                        size: statValueSize,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: statLabelSize, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

// MARK: - Compact

struct CompactView: View {
    enum Region {
        case leading, trailing
    }

    let region: Region
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        switch region {
        case .leading:
            Text("00:00:00")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(
                        timerInterval: context.attributes.startTime...Date.distantFuture,
                        countsDown: false
                    )
                    .monospacedDigit()
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 5)

        case .trailing:
            Text(context.state.netProfit, format: .currency(code: "USD"))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Minimal

struct MinimalView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            Text(context.state.netProfit, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Attributes

extension SessionActivityAttributes {
    fileprivate static var preview: SessionActivityAttributes {
        SessionActivityAttributes(startTime: Date())
    }
}

extension SessionActivityAttributes.ContentState {
    fileprivate static var active: SessionActivityAttributes.ContentState {
        SessionActivityAttributes.ContentState(
            totalEarnings: 32.50,
            netProfit: 28.50,
            netHourlyProfit: 18.00,
            netPerMile: 2.30,
            deliveryCount: 3,
            totalMiles: 12.4,
            lastUpdated: Date()
        )
    }
}

// MARK: Preview

#Preview(
    "Lock Screen / Banner",
    as: .content,
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.compact),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}

#Preview(
    "Dynamic Island Expanded",
    as: .dynamicIsland(.expanded),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}

#Preview(
    "Dynamic Island Minimal",
    as: .dynamicIsland(.minimal),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
