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
            CompactTimer(startTime: context.attributes.startTime)

        case .trailing:
            Text(context.state.netProfit, format: .currency(code: context.state.currencyCode))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .contentTransition(.numericText())
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

#Preview(
    "Dynamic Island Compact - Over 1 Hour",
    as: .dynamicIsland(.compact),
    using: SessionActivityAttributes.previewOverOneHour
) {
    SessionInfoLiveActivityLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.active
}
