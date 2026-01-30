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
    var body: some Scene {
        WindowGroup {
            VenturaTabs()
        }
        .modelContainer(for: [UserSettings.self, Session.self])
    }
}

