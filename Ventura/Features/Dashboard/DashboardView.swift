//
//  DashboardView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI
import WeatherKit
import SwiftData

internal import _LocationEssentials

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionManager: SessionManager
    @ObservedObject private var weatherManager = WeatherManager.shared
    private let locationTracker = LocationTracker.shared
    @ObservedObject private var gasFetcher = GasPriceFetcher.shared
    
    // PERFORMANCE: Manual fetch instead of @Query to prevent synchronous
    // re-evaluation on every foreground resume. Dashboard only needs the most
    // recent completed session for the "Last Session" card.
    @State private var lastSession: Session?
    
    private func loadLastSession() async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffDate = Calendar.current.startOfDay(for: thirtyDaysAgo)
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.endTimestamp != nil && $0.startTimestamp >= cutoffDate
            },
            sortBy: [SortDescriptor(\.endTimestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            lastSession = try modelContext.fetch(descriptor).first
        } catch {
            print("DashboardView: Failed to fetch last session: \(error)")
        }
    }
    
    @Query private var settings: [UserSettings]
    
    @State private var showEndAlert = false
    @State private var startStopTrigger = false
    @State private var showSummarySheet = false
    @State private var showDriveSheet = false
    
    var activeSession: Session? {
        sessionManager.activeSession
    }
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Session Controls Section
                    
                    // Session Stats Card (only during active session)
                    if activeSession != nil {
                        LiveSessionStats(
                            ticker: sessionManager.ticker,
                            session: activeSession,
                            settings: settings.first ?? UserSettings(),
                            isLive: true,
                            showHomeStats: settings.first?.homeLatitude != nil
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Start/Stop Button
                    if activeSession != nil {
                        // STOP BUTTON
                        Button {
                            showEndAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("End Session")
                            }
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.red)
                            .cornerRadius(20)
                            .glassModifier(
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }
                        .sensoryFeedback(.success, trigger: startStopTrigger)
                        .confirmationDialog(
                            "End Session?",
                            isPresented: $showEndAlert,
                            titleVisibility: .visible
                        ) {
                            Button("End Session", role: .destructive) {
                                startStopTrigger.toggle()
                                stopSession()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "Are you sure you want to end your current session?"
                            )
                        }
                    } else {
                        // START BUTTON
                        Button {
                            startStopTrigger.toggle()
                            startSession()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Session")
                            }
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.green)
                            .cornerRadius(20)
                            .glassModifier(
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .sensoryFeedback(
                                .success,
                                trigger: startStopTrigger
                            )
                        }
                    }
                    
                  
                    
                    
                    // Live Map Card (only during active session)
                    if activeSession != nil {
                        LiveSessionMapCard()
                            .environmentObject(sessionManager)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onTapGesture {
                                showDriveSheet = true 
                            }
                    }
                    
                    
                    // Main Weather Card
                    CurrentConditionsCard()
                        .environmentObject(weatherManager)
                    
                    // Earnings Comparison
                    EarningsComparisonCard()
                    
                    // Gas Prices Card
                    if gasFetcher.isLoading || !gasFetcher.stations.isEmpty || gasFetcher.lastError != nil {
                        GasPricesCard(
                            stations: gasFetcher.stations,
                            isLoading: gasFetcher.isLoading,
                            lastFetchTime: gasFetcher.lastFetchTime,
                            userLocation: locationTracker.currentLocation ?? weatherManager.lastKnownLocation,
                            error: gasFetcher.lastError,
                            onRetry: {
                                let targetLocation = locationTracker.currentLocation ?? weatherManager.lastKnownLocation
                                if let loc = targetLocation {
                                    gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, force: true)
                                } else {
                                    weatherManager.retryFetch()
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

             
                    
                    // Precipitation Alert
                    if weatherManager.ui?.isPrecipitationAlert == true {
                        PrecipWarningCard()
                            .environmentObject(weatherManager)
                    }
                    
                    // Safety Cards
                    if weatherManager.ui?.isLowVisibility == true {
                        VisibilityCard()
                            .environmentObject(weatherManager)
                    }
                    
                    if weatherManager.ui?.isHighWind == true {
                        WindCard()
                            .environmentObject(weatherManager)
                    }
                    
                    if (weatherManager.ui?.officialAlerts.isEmpty == false) {
                        OfficialWeatherAlertCard()
                            .environmentObject(weatherManager)
                    }
                    
                    if (weatherManager.ui?.extremeColdAlert == true) || (weatherManager.ui?.extremeHeatAlert == true) {
                        ExtremeTempCard()
                            .environmentObject(weatherManager)
                    }
                
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .appBackground(style: settings.first?.backgroundStyle ?? .mesh)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }


        .sheet(isPresented: $showDriveSheet) {
            NavigationStack {
                DriveView()
            }
            // Add presentationDetents if needed, or leave as default.
            // User requested "a sheet that pops up".
             #if os(iOS)
            .presentationDetents([.large])
             #endif
        }
        .sheet(isPresented: $showSummarySheet) {
            if let sessionToShow = sessionManager.lastEndedSession
                ?? lastSession
            {
                NavigationStack {
                    SessionSummarySheet(
                        session: sessionToShow,
                        isPresentedAsSheet: true
                    )
                }
                #if os(iOS)
                    .presentationDetents([.fraction(0.95)])
                    .presentationDragIndicator(.visible)
                #endif
            }
        }
        .task {
            // Load last session asynchronously (won't block main thread on foreground)
            await loadLastSession()
            
            if let userSettings = settings.first {
                weatherManager.configure(with: userSettings)
            }
            // Trigger initial fetch
            weatherManager.refreshWeatherIfNeeded(for: locationTracker.currentLocation)
            
            let targetLocation = locationTracker.currentLocation ?? weatherManager.lastKnownLocation
            if let loc = targetLocation {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
        // Removed .onChange(of: locationTracker.currentLocation) to prevent 1Hz re-renders.
        // Side effects should be handled by specific components or Managers.
        .onChange(of: weatherManager.lastKnownLocation) { _, newLoc in
            if let loc = newLoc, !gasFetcher.isLoading && gasFetcher.lastError == nil {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
        .onChange(of: sessionManager.activeSession) { oldSession, newSession in
            // If session just ended
            if oldSession != nil && newSession == nil {
                showDriveSheet = false
                // Add a small delay to allow drive sheet to dismiss before showing summary
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSummarySheet = true
                }
            }
        }
    }
    
    private func startSession() {
        sessionManager.startSession()
        showDriveSheet = true 
    }
    
    private func stopSession() {
        sessionManager.stopSession()
        // Summary sheet will be triggered by onChange
    }
}



#Preview("Normal") {
    let container = PreviewHelper.makeContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
        .onAppear {
            PreviewHelper.configureDashboardPreview(weather: .mock)
        }
}

#Preview("Critical Alerts") {
    let container = PreviewHelper.makeContainer()
    return VenturaTabs()
        .modelContainer(container)
        .environmentObject(SessionManager())
        .onAppear {
            PreviewHelper.configureDashboardPreview(weather: .criticalAll)
        }
}
