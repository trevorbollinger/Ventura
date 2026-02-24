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
    @Environment(SessionManager.self) private var sessionManager
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
    
    // Settings come from sessionManager.cachedSettings (no @Query = no synchronous
    // SwiftData fetch on foreground resume)
    private var currentSettings: UserSettings { sessionManager.cachedSettings ?? UserSettings() }
    
    @State private var showEndAlert = false
    @State private var startStopTrigger = false
    @State private var showSummarySheet = false
    @State private var showDriveSheet = false
    
    var activeSession: Session? {
        sessionManager.activeSession
    }
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Session Controls Section
                    
                    // Session Stats Card (only during active session)
                    if activeSession != nil {
                        LiveSessionStats(
                            ticker: sessionManager.ticker,
                            session: activeSession,
                            settings: currentSettings,
                            isLive: true,
                            showHomeStats: currentSettings.homeLatitude != nil
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture {
                            showDriveSheet = true
                        }
                    }
                    

                    // Live Map Card (only during active session)
                    if activeSession != nil {
                        LiveSessionMapCard()
                            .environment(sessionManager)
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
                .padding(.bottom, 80) // Leave room for floating button
            }
            .appBackground(style: currentSettings.backgroundStyle)
            .navigationBarTitleDisplayMode(.inline)
        }
        
        // MARK: - Floating Start/Stop Button
        Group {
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
                    .glassModifier(in: RoundedRectangle(cornerRadius: 20))
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
                    Text("Are you sure you want to end your current session?")
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
                    .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                    .sensoryFeedback(.success, trigger: startStopTrigger)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        } // end ZStack
        .sheet(isPresented: $showDriveSheet) {
            NavigationStack {
                DriveView()
            }
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
            await loadLastSession()
            weatherManager.configure(with: currentSettings)
            weatherManager.refreshWeatherIfNeeded(for: locationTracker.currentLocation)
            let targetLocation = locationTracker.currentLocation ?? weatherManager.lastKnownLocation
            if let loc = targetLocation {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
        .onChange(of: weatherManager.lastKnownLocation) { _, newLoc in
            if let loc = newLoc, !gasFetcher.isLoading && gasFetcher.lastError == nil {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
        .onChange(of: sessionManager.activeSession) { oldSession, newSession in
            if oldSession != nil && newSession == nil {
                showDriveSheet = false
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
    VenturaTabs()
        .modelContainer(container)
        .environment(SessionManager())
        .onAppear {
            PreviewHelper.configureDashboardPreview(weather: .mock)
        }
}

#Preview("Critical Alerts") {
    let container = PreviewHelper.makeContainer()
    VenturaTabs()
        .modelContainer(container)
        .environment(SessionManager())
        .onAppear {
            PreviewHelper.configureDashboardPreview(weather: .criticalAll)
        }
}
