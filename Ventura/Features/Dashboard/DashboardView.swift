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
    @ObservedObject private var locationTracker = LocationTracker.shared
    @ObservedObject private var gasFetcher = GasPriceFetcher.shared
    
    @Query(
        filter: #Predicate<Session> { $0.endTimestamp != nil },
        sort: \Session.endTimestamp,
        order: .reverse
    )
    private var completedSessions: [Session]
    
    @Query private var settings: [UserSettings]
    
    @State private var showEndAlert = false
    @State private var startStopTrigger = false
    @State private var showSummarySheet = false
    @State private var navigationPath = NavigationPath()
    
    var activeSession: Session? {
        sessionManager.activeSession
    }
    
    var lastSession: Session? {
        completedSessions.first
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Session Controls Section
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
                    
                    // Session Stats Card (only during active session)
                    if activeSession != nil {
                        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                            SessionStatsCard(
                                session: activeSession,
                                isLive: true,
                                timelineDate: timeline.date,
                                showHomeStats: settings.first?.homeLatitude != nil
                            )
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Live Map Card (only during active session)
                    if activeSession != nil {
                        NavigationLink(value: "DriveView") {
                            LiveSessionMapCard()
                                .environmentObject(sessionManager)
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                       
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
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { value in
                if value == "DriveView" {
                    DriveView()
                }
            }
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.9),
            value: activeSession != nil
        )
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
        .onAppear {
            weatherManager.refreshWeatherIfNeeded(for: locationTracker.currentLocation)
            
            // Always request a fetch on appear - the gasFetcher handles its own 2-hour throttling internally.
            let targetLocation = locationTracker.currentLocation ?? weatherManager.lastKnownLocation
            if let loc = targetLocation {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
        .onChange(of: locationTracker.currentLocation) { _, newLoc in
            if let loc = newLoc {
                weatherManager.refreshWeatherIfNeeded(for: loc)
            }
        }
        .onChange(of: weatherManager.lastKnownLocation) { _, newLoc in
            // Trigger background gas fetch when location is first acquired
            if let loc = newLoc, !gasFetcher.isLoading && gasFetcher.lastError == nil {
                gasFetcher.fetchGasPrices(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        }
    }
    
    private func startSession() {
        sessionManager.startSession()
        navigationPath.append("DriveView")
    }
    
    private func stopSession() {
        sessionManager.stopSession()
        showSummarySheet = true
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
