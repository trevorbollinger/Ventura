//
//  SessionInfoLiveActivityMinimalView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct MinimalView: View {
    let context: ActivityViewContext<SessionActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            Text(context.state.netProfit, format: .currency(code: context.state.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Preview

#Preview(
    "Dynamic Island Minimal",
    as: .dynamicIsland(.minimal),
    using: SessionActivityAttributes.preview
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
