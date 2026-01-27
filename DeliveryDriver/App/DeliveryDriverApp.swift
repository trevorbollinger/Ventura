//
//  DeliveryDriverApp.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

@main
struct DeliveryDriverApp: App {
    var body: some Scene {
        WindowGroup {
            DriverTabs()
        }
        .modelContainer(for: UserSettings.self)
    }
}

