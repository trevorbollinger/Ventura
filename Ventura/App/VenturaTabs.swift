//
//  DriverTabs.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

enum Tab: Int, CaseIterable, Identifiable {
    case dashboard
    case stats
    case settings
    case history
    case market
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Drive"
        case .stats: return "Analytics"
        case .history: return "History"
        case .market: return "Market"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "car.fill"
        case .stats: return "chart.bar.xaxis"
        case .history: return "clock.fill"
        case .market: return "storefront.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct VenturaTabs: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionManager: SessionManager
    
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showingOnboarding = false
    
    // Toggle this to force onboarding to show every time
    private let debugAlwaysShowOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DriveView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)
            
            StatsView()
                .tabItem {
                    Label(Tab.stats.title, systemImage: Tab.stats.icon)
                }
                .tag(Tab.stats)
            
            HistoryView()
                .tabItem {
                    Label(Tab.history.title, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)
            
            SettingsView()
                .tabItem {
                    Label(Tab.market.title, systemImage: Tab.market.icon)
                }
                .tag(Tab.market)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .onAppear {
            if !hasSeenOnboarding || debugAlwaysShowOnboarding {
                showingOnboarding = true
                hasSeenOnboarding = true
            }
            
            // Configure SessionManager
            sessionManager.configure(modelContext: modelContext)
        }
    }
}


#Preview {
    let container = PreviewHelper.makeContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
}
