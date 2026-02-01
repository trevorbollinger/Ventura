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
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            VenturaTabs()
                .environmentObject(sessionManager)
        }
        .modelContainer(for: [UserSettings.self, Session.self])
    }
}

