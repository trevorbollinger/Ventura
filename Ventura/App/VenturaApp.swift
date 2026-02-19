//
//  VenturaApp.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

@main
struct VenturaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // TEST 3b: SessionManager + TabView, but @Query stripped from VenturaTabs
    @StateObject private var sessionManager = SessionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            VenturaTabs()
                .environmentObject(sessionManager)
        }
        .modelContainer(for: [UserSettings.self, Session.self])
    }
}
