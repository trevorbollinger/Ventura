//
//  SessionInfoLiveActivityLockScreenView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SessionActivityView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            LiveActivityHeader(
                title: "Tracking Session",
                startTime: context.attributes.startTime
            )
            Divider()
            LiveActivityProfitHero(
                profit: context.state.netProfit,
                currencyCode: context.state.currencyCode
            )
            LiveActivityStatsRow(
                state: context.state,
                attributes: context.attributes
            )
        }
        .frame(maxWidth: .infinity)
        .padding(13)
        
    }
}

// MARK: - Preview

#Preview(
    "Lock Screen / Banner",
    as: .content,
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
