//
//  WeatherManager.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import Foundation
import WeatherKit
import CoreLocation
import Combine
import SwiftUI

/// Manages WeatherKit interactons with strict API usage controls.
/// Implements "Smart Fetching":
/// 1. 15-Minute Rule: Caches data for 15 minutes.
/// 2. Location Debouncing: Only refetches if location changes significantly (City-level/5km).
/// 3. Session Lock: Prevents rapid re-fetches on view re-appear.
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var ui: WeatherUIModel? // New Mockable UI State
    @Published var isLoading = false
    @Published var error: String?
    
    // Cache State
    private var lastFetchTime: Date?
    @Published var lastKnownLocation: CLLocation?
    private var fullWeatherCache: Weather? // Helper to allow re-mapping units instantly
    private var currentWeather: CurrentWeather? // Internal use only now
    
    // Configuration
    private let cacheDuration: TimeInterval = 15 * 60 // 15 Minutes
    private let locationDebounceDistance: CLLocationDistance = 5000 // 5km (City-level accuracy roughly)
    
    // Localization Configuration (Default to US/Imperial, updated via configure())
    var temperatureUnit: UnitTemperature = .fahrenheit
    var distanceUnit: UnitLength = .miles
    
    private let service = WeatherService.shared
    private let locationManager = CLLocationManager()
    
    // For Preview Caching
    var isPreview = false
    var mockData: WeatherUIModel = WeatherUIModel(
        temperature: "72°",
        conditionIcon: "sun.max.fill",
        conditionDescription: "Sunny",
        apparentTemperature: "75°",
        wind: "5 mph N",
        uvIndex: "3 (Moderate)",
        humidity: "45%",
        visibility: "10 mi",
        pressure: "29.92 inHg",
        cloudCover: "0%",
        highTemperature: "78°",
        lowTemperature: "65°",
        precipitationText: "No precipitation expected",
        precipitationIcon: "sun.min.fill",
        precipitationChance: "0%",
        isLowVisibility: false,
        windSpeed: "5 mph",
        windGust: "8 mph",
        isHighWind: false,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: false,
        officialAlerts: [],
        precipitationIntensityForecast: [],
        locationTimeZone: .current
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        // We only need coarse accuracy for weather in most cases, or moderate.
        // kCLLocationAccuracyKilometer is usually sufficient for weather.
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        startMonitoring()
    }
    
    func configure(with settings: UserSettings) {
        let newDist = settings.distanceUnit.unit
        
        // Re-map if units changed OR if we just loaded defaults and want to ensure consistency
        if self.distanceUnit != newDist {
            self.distanceUnit = newDist
            
            // If we have cached weather, re-map it immediately to update UI with new units
            if let weather = fullWeatherCache, let location = lastKnownLocation {
                print("WeatherManager: 🔄 Updating Weather Units (Distance: \(newDist.symbol))")
                self.mapToUI(
                    weather.currentWeather,
                    daily: weather.dailyForecast,
                    hourly: weather.hourlyForecast,
                    minute: weather.minuteForecast,
                    alerts: weather.weatherAlerts,
                    location: location
                )
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Starts observing the global LocationTracker to fetch weather automatically in the background.
    func startMonitoring() {
        // Observe LocationTracker.shared.currentLocation
        // We use the singleton directly here since this is also a singleton service.
        LocationTracker.shared.$currentLocation
            .sink { [weak self] location in
                self?.refreshWeatherIfNeeded(for: location)
            }
            .store(in: &cancellables)
    }
    
    /// Triggered from UI (e.g. onAppear). Decides whether to actually fetch or use cache.
    func refreshWeatherIfNeeded(for location: CLLocation?) {
        if let location = location {
            // Case A: Location provided by Tracker (Active Session)
            if shouldFetch(for: location) {
                fetchWeather(for: location)
            } else {
                print("WeatherManager: Using cached weather. (Rules: <15m or same city)")
            }
        } else {
            // Case B: No location provided (Tracker Idle)
            // Request a one-shot fix specifically for weather
            print("WeatherManager: No location context. Requesting one-shot location...")
            requestOneShotLocation()
        }
    }
    
    /// Retries fetching weather using the last known location or requesting a fresh one.
    func retryFetch() {
        if let lastLocation = lastKnownLocation {
            // Force fetch
            fetchWeather(for: lastLocation)
        } else {
            // No last location, try one-shot
            requestOneShotLocation()
        }
    }
    
    // MARK: - internal Location Handling
    
    private func requestOneShotLocation() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("WeatherManager: Location permission denied.")
            self.error = "Location Access Denied"
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        print("WeatherManager: 📍 One-shot location received: \(location.coordinate)")
        
        // Once we get a location, we check if we should fetch weather for it
        if shouldFetch(for: location) {
            fetchWeather(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // If requestLocation() fails (e.g. timeout), it calls this.
        print("WeatherManager: One-shot location failed: \(error.localizedDescription)")
        if self.ui == nil {
             self.error = "Location Unavailable"
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    // MARK: - Smart Fetching Logic
    
    private func shouldFetch(for location: CLLocation) -> Bool {
        // Rule 0: If we have no data, fetch.
        guard let lastTime = lastFetchTime, let lastLoc = lastKnownLocation else {
            return true
        }
        
        // Rule 1: 15-Minute Rule
        let timeSinceLastFetch = Date().timeIntervalSince(lastTime)
        if timeSinceLastFetch > cacheDuration {
            print("WeatherManager: Cache expired (\(Int(timeSinceLastFetch/60))m). Fetching.")
            return true
        }
        
        // Rule 2: Location Debouncing
        // If we are within 15 minutes, ONLY fetch if we moved significantly (City level).
        let distance = location.distance(from: lastLoc)
        if distance > locationDebounceDistance {
            print("WeatherManager: Location changed significantly (\(Int(distance))m). Fetching.")
            return true
        }
        
        return false
    }
    
    // MARK: - Fetching
    
    private func fetchWeather(for location: CLLocation) {
        guard !isLoading else { return }
        
        // PREVIEW SAFEGUARD: Don't burn API quota in Xcode Previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || isPreview {
            print("WeatherManager: ⚠️ PREVIEW MODE - Returning Mock Data")
            self.ui = self.mockData
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                print("WeatherManager: ☁️ FETCHING NEW WEATHER DATA ☁️")
                let weather = try await service.weather(for: location)
                
                await MainActor.run {
                    self.currentWeather = weather.currentWeather
                    self.fullWeatherCache = weather // Cache full object for unit changes
                    self.lastFetchTime = Date()
                    self.lastKnownLocation = location
                    self.isLoading = false
                    
                    // Map to UI Model
                    self.mapToUI(weather.currentWeather, daily: weather.dailyForecast, hourly: weather.hourlyForecast, minute: weather.minuteForecast, alerts: weather.weatherAlerts, location: location)
                }
            } catch {
                print("WeatherManager: Error fetching weather: \(error)")
                await MainActor.run {
                    // Check for Auth/Capability errors
                    let nsError = error as NSError
                    if nsError.domain.contains("WeatherDaemon") || nsError.code == 2 {
                         self.error = "WeatherKit Capability Missing"
                    } else {
                        self.error = error.localizedDescription
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    private func mapToUI(_ weather: CurrentWeather, daily: Forecast<DayWeather>, hourly: Forecast<HourWeather>?, minute: Forecast<MinuteWeather>?, alerts: [WeatherAlert]?, location: CLLocation) {
        // Temperature Rounding Style
        var tempStyle = Measurement<UnitTemperature>.FormatStyle.measurement(width: .narrow, usage: .weather)
        tempStyle.numberFormatStyle = .number.precision(.fractionLength(0))
        
        let targetDistUnit = self.distanceUnit
        
        // Calculate precipitation info (text + icon + chance)
        let precipInfo = calculatePrecipitationInfo(minute: minute, hourly: hourly, daily: daily)
        
        // Use device's current timezone for display
        // For normal use, device location = weather location, so this works correctly
        let locationTimeZone = TimeZone.current
        
        self.ui = WeatherUIModel(
            temperature: weather.temperature.formatted(tempStyle),
            conditionIcon: weather.symbolName,
            conditionDescription: weather.condition.description,
            apparentTemperature: weather.apparentTemperature.formatted(tempStyle),
            wind: "\(weather.wind.speed.converted(to: targetDistUnit == .kilometers ? .kilometersPerHour : .milesPerHour).formatted()) \(weather.wind.direction.formatted())",
            uvIndex: "\(weather.uvIndex.value) (\(weather.uvIndex.category.description))",
            humidity: weather.humidity.formatted(.percent),
            visibility: weather.visibility.converted(to: targetDistUnit).formatted(),
            pressure: weather.pressure.formatted(),
            cloudCover: weather.cloudCover.formatted(.percent),
            highTemperature: daily[0].highTemperature.formatted(tempStyle),
            lowTemperature: daily[0].lowTemperature.formatted(tempStyle),
            precipitationText: precipInfo.text,
            precipitationIcon: precipInfo.icon,
            precipitationChance: precipInfo.chance,
            
            // Safety Data
            isLowVisibility: weather.visibility.converted(to: .miles).value < 0.5, // Logic remains on internal standard (miles) for safety thresholds
            windSpeed: weather.wind.speed.converted(to: targetDistUnit == .kilometers ? .kilometersPerHour : .milesPerHour).formatted(),
            windGust: weather.wind.gust?.converted(to: targetDistUnit == .kilometers ? .kilometersPerHour : .milesPerHour).formatted() ?? (targetDistUnit == .kilometers ? "0 km/h" : "0 mph"),
            isHighWind: (weather.wind.gust?.converted(to: .milesPerHour).value ?? 0) > 30, // Logic remains standardized
            extremeColdAlert: weather.temperature.converted(to: .fahrenheit).value < -10,
            extremeHeatAlert: weather.temperature.converted(to: .fahrenheit).value > 95,
            isPrecipitationAlert: precipInfo.chance != "0%",
            officialAlerts: alerts?.map { 
                WeatherAlertModel(
                    summary: $0.summary,
                    detailsURL: $0.detailsURL,
                    source: $0.source,
                    severity: $0.severity.description
                )
            } ?? [],
            precipitationIntensityForecast: {
                guard let hourly = hourly else { return [] }
                let now = Date()
                
                // Filter to only future hours
                let futureHours = hourly.filter { $0.date >= now }
                
                // Find all hours with significant precipitation (>=30%)
                let rainIndices = futureHours.enumerated().filter { $0.element.precipitationChance >= 0.3 }.map { $0.offset }
                
                if let firstRainIndex = rainIndices.first, let lastRainIndex = rainIndices.last {
                    // Start 1 hour before rain begins (if available)
                    let startIndex = max(0, firstRainIndex - 1)
                    // End 1 hour after rain stops (if available)
                    let endIndex = min(futureHours.count - 1, lastRainIndex + 1)
                    
                    // Get the slice from start to end (inclusive)
                    return Array(futureHours[startIndex...endIndex])
                        .map { PrecipDataPoint(date: $0.date, intensity: $0.precipitationChance) }
                } else {
                    // No significant precipitation found, return empty (card won't show anyway)
                    return []
                }
            }(),
            locationTimeZone: locationTimeZone
        )
    }
    
    /// Returns a URL that opens the Apple Weather app for the current location.
    var weatherURL: URL {
        if let location = lastKnownLocation {
            // This format works on iOS to open a specific coordinate in Weather app
            return URL(string: "https://weather.apple.com/?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)") ?? URL(string: "weather://")!
        }
        return URL(string: "weather://")!
    }
    
    private func calculatePrecipitationInfo(minute: Forecast<MinuteWeather>?, hourly: Forecast<HourWeather>?, daily: Forecast<DayWeather>) -> (text: String, icon: String, chance: String) {
        
        func getIcon(for precipitation: Precipitation) -> String {
            switch precipitation {
            case .hail: return "cloud.hail.fill"
            case .mixed: return "cloud.sleet.fill"
            case .rain: return "cloud.rain.fill"
            case .sleet: return "cloud.sleet.fill"
            case .snow: return "snowflake"
            default: return "cloud.rain.fill"
            }
        }
        
        func precipName(for precipitation: Precipitation) -> String {
            switch precipitation {
            case .hail: return "Hail"
            case .mixed: return "Mixed precip"
            case .rain: return "Rain"
            case .sleet: return "Sleet"
            case .snow: return "Snow"
            default: return "Precipitation"
            }
        }
        
        func formatChance(_ probability: Double) -> String {
            return "\(Int(probability * 100))%"
        }
        
        // 1. Check Minute Forecast (Next hour) - HIGHEST PRIORITY
        if let minute = minute {
            if let start = minute.first(where: { $0.precipitationChance >= 0.3 }) {
                let diff = start.date.timeIntervalSinceNow
                let type = precipName(for: start.precipitation)
                let icon = getIcon(for: start.precipitation)
                // Find max chance in the minute forecast
                let maxChance = minute.map { $0.precipitationChance }.max() ?? start.precipitationChance
                let chance = formatChance(maxChance)
                
                if diff <= 0 {
                    return ("\(type) starting now", icon, chance)
                } else if diff < 3600 {
                    let minutes = Int(diff / 60)
                    return ("\(type) in \(minutes) min", icon, chance)
                }
            }
        }
        
        // 2. Check Hourly Forecast (Next 24h)
        if let hourly = hourly {
             if let hour = hourly.first(where: { $0.precipitationChance >= 0.3 && $0.date > Date() }) {
                 let diff = hour.date.timeIntervalSinceNow
                 let type = precipName(for: hour.precipitation)
                 let icon = getIcon(for: hour.precipitation)
                 // Find max chance in next 6 hours for better accuracy
                 let next6Hours = hourly.prefix(6)
                 let maxChance = next6Hours.map { $0.precipitationChance }.max() ?? hour.precipitationChance
                 let chance = formatChance(maxChance)
                 
                 if diff < 3600 {
                     return ("\(type) starting soon", icon, chance)
                 } else if diff < 86400 {
                     if Calendar.current.isDateInToday(hour.date) {
                         return ("\(type) at " + hour.date.formatted(date: .omitted, time: .shortened), icon, chance)
                     } else {
                         return ("\(type) tomorrow at " + hour.date.formatted(date: .omitted, time: .shortened), icon, chance)
                     }
                 }
             }
        }
        
        // 3. (REMOVED) Daily Forecast check is no longer used for critical alert (limited to 24h).
        
        // Neutral/None
        return ("No precipitation expected in the next 24 hours", "sun.min.fill", "0%")
    }
    
    // MARK: - Formatters
    
    // We now expose a UI-ready model instead of raw CurrentWeather
    
}

struct WeatherUIModel {
    let temperature: String
    let conditionIcon: String
    let conditionDescription: String
    let apparentTemperature: String
    
    let wind: String
    let uvIndex: String
    let humidity: String
    let visibility: String
    let pressure: String
    let cloudCover: String
    let highTemperature: String
    let lowTemperature: String
    
    let precipitationText: String
    let precipitationIcon: String
    let precipitationChance: String
    
    // Safety Alerts
    let isLowVisibility: Bool
    let windSpeed: String
    let windGust: String
    let isHighWind: Bool
    let extremeColdAlert: Bool
    let extremeHeatAlert: Bool
    let isPrecipitationAlert: Bool
    let officialAlerts: [WeatherAlertModel]
    let precipitationIntensityForecast: [PrecipDataPoint]
    let locationTimeZone: TimeZone
}

struct PrecipDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let intensity: Double
}

struct WeatherAlertModel {
    let summary: String
    let detailsURL: URL
    let source: String
    let severity: String
}
