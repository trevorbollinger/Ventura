//
//  DriverTabs.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI

enum Tab: Int, CaseIterable, Identifiable {
    case dashboard
    case stats
    case settings
    case history
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .stats: return "Stats"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "car.fill"
        case .stats: return "chart.bar.fill"
        case .history: return "list.bullet"
        case .settings: return "gearshape.fill"
        }
    }
}

struct DriverTabs: View {
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showingOnboarding = false
    
    // Toggle this to force onboarding to show every time
    private let debugAlwaysShowOnboarding = true

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
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
        }
    }
}

#Preview {
    DriverTabs()
}
