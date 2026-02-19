//
//  DriverTabs.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData
import CoreLocation

enum Tab: Int, CaseIterable, Identifiable {
    case dashboard
    case drive
    case stats
    case settings
    case history
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .stats: return "Analytics"
        case .history: return "History"
        case .dashboard: return "Home"
        case .drive: return "Drive"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .stats: return "chart.bar.xaxis"
        case .history: return "clock.fill"
        case .dashboard: return "house.fill"
        case .drive: return "car.fill"
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
    
    private let debugAlwaysShowOnboarding = false
    
    @Query private var settings: [UserSettings]

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
