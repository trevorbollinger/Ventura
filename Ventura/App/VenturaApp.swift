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
    // Initialize WeatherManager to start background monitoring immediately
    private let weatherManager = WeatherManager.shared

    var body: some Scene {
        WindowGroup {
            VenturaTabs()
                .environmentObject(sessionManager)
                // GLOBAL BACKGROUND LOADER: Keeps the gas price WebView alive
                .background(
                    WebViewContainer(webView: GasPriceFetcher.shared.webView)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                )
        }
        .modelContainer(for: [UserSettings.self, Session.self])
    }
}

