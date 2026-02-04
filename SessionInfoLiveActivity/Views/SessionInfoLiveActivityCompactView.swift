//
//  SessionInfoLiveActivityCompactView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

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
            Text(context.state.netProfit, format: .currency(code: context.state.currencyCode))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.compact),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
