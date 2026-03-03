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
    case sessions
    case analytics
    case map
    case settings
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .sessions: return "Sessions"
        case .analytics: return "Analytics"
        case .map: return "Map"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .sessions: return "clock.fill"
        case .analytics: return "chart.bar.fill"
        case .map: return "map.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct VenturaTabs: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    // DO NOT use @Query here. VenturaTabs is the ROOT of the view tree.
    // Any @Query at this level causes the ENTIRE app to re-render on every
    // modelContext.save(). Use sessionManager.cachedSettings instead.
    private var currentSettings: UserSettings { sessionManager.cachedSettings ?? UserSettings() }
    
    @State private var showingOnboarding = false
    
    private let debugAlwaysShowOnboarding = false
    

    var body: some View {
            
        
                
            TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)
            
            SessionsView()
                .tabItem {
                    Label(Tab.sessions.title, systemImage: Tab.sessions.icon)
                }
                .tag(Tab.sessions)

            AnalyticsView()
                .tabItem {
                    Label(Tab.analytics.title, systemImage: Tab.analytics.icon)
                }
                .tag(Tab.analytics)

            AllDrivingRoutesView()
                .tabItem {
                    Label(Tab.map.title, systemImage: Tab.map.icon)
                }
                .tag(Tab.map)
            
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
        .fullScreenCover(isPresented: Binding(
            get: { sessionManager.activeSession != nil },
            set: { _ in }
        )) {
            DriveView()
        }
        .task {
            if !hasSeenOnboarding || debugAlwaysShowOnboarding {
                showingOnboarding = true
                hasSeenOnboarding = true
            }
            sessionManager.configure(modelContext: modelContext)
            await sessionManager.loadInitialData()
        }
    }
}


#Preview {
    let container = PreviewHelper.makeContainer()
    VenturaTabs()
        .modelContainer(container)
        .environment(SessionManager())
}

#Preview("Empty State") {
    let container = PreviewHelper.makeEmptyContainer()
    VenturaTabs()
        .modelContainer(container)
        .environment(SessionManager())
}
