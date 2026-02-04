//
//  SessionInfoLiveActivityExpandedView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

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
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .padding(.leading, 10)
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
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .font(.system(size: headerSize, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            }
            .padding(.trailing, 10)
            
        case .center:
            LiveActivityProfitHero(profit: context.state.netProfit)

        case .bottom:
            LiveActivityStatsRow(state: context.state, attributes: context.attributes)
        }
    }
}

// MARK: - Preview

#Preview(
    "Dynamic Island Expanded",
    as: .dynamicIsland(.expanded),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
