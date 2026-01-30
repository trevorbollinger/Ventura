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
                //
                //                DynamicIslandExpandedRegion(.center) {
                //                    ExpandedView(region: .center, context: context)
                //                }

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
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Delivery Session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(context.attributes.startTime, style: .timer)
                        .font(
                            .system(size: 32, weight: .bold, design: .rounded)
                        )
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Earnings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(
                        context.state.netProfit,
                        format: .currency(code: "USD")
                    )
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                }
            }
            .padding(.bottom, 12)

            Divider()
                .background(.white.opacity(0.2))
                .padding(.bottom, 12)

            HStack {
                Text("\(context.state.totalMiles, specifier: "%.1f") mi")
                    .fontWeight(.semibold)

                    .font(.subheadline)

                Spacer()

                Text("\(context.state.netHourlyProfit, format: .currency(code: "USD"))/hr")
                    .fontWeight(.semibold)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Expanded

struct ExpandedView: View {
    enum Region {
        case leading, trailing, center, bottom
    }

    let region: Region
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        switch region {
        case .leading:
            // Miles

            Text("\(context.state.totalMiles, specifier: "%.1f") mi")
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

        case .trailing:
            // 1. Timer (Large, Centered)
            Text(context.attributes.startTime, style: .timer)
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
        case .center:
            // Empty as requested
            Spacer()

        case .bottom:

            // 2. Stats Row (Miles, Net, Hourly)
            HStack(spacing: 20) {

                // Net Profit
                VStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(
                        context.state.netProfit,
                        format: .currency(code: "USD")
                    )
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                }

                // Hourly
                VStack(spacing: 2) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        Text(
                            context.state.netHourlyProfit,
                            format: .currency(code: "USD")
                        )
                        .font(.subheadline)
                        .fontWeight(.bold)
                        Text("/h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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
            Text("\(context.state.netHourlyProfit, format: .currency(code: "USD"))/hr")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.green)
//                .padding(.leading, 4)

        case .trailing:
            Text(context.state.netProfit, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.green)
//                .padding(.trailing, 4)
        }
    }
}

// MARK: - Minimal

struct MinimalView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        Image(systemName: "car.fill")
            .foregroundStyle(.orange)
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
