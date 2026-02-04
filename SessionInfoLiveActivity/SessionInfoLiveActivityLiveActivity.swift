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
