//
//  LiveSessionStats.swift
//  Ventura
//
//  Created by Auto-Agent on 2/5/26.
//

import SwiftUI
import SwiftData

/// A "Smart" view that observes the high-frequency ticker.
/// This isolates the 1Hz redraws to this component only.
struct LiveSessionStats: View {
    @EnvironmentObject private var sessionManager: SessionManager
    // We observe the ticker directly here
    @ObservedObject var ticker: SessionTicker
    
    let session: Session?
    let settings: UserSettings
    let isLive: Bool
    let showHomeStats: Bool
    
    var body: some View {
        SessionStatsCard(
            session: session,
            settings: settings,
            isLive: isLive,
            timelineDate: Date(),
            showHomeStats: showHomeStats,
            sessionState: ticker.state
        )
    }
}
