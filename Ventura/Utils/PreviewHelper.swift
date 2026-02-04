//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
struct PreviewHelper {
    
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Session.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // Populate with data
        let sessions = generateMockSessions()
        for session in sessions {
            container.mainContext.insert(session)
        }
        
        // Also insert a default UserSettings if needed
        let settings = UserSettings()
        container.mainContext.insert(settings)
        
        return container
    }
    
    static func makeEmptyContainer() -> ModelContainer {
        let schema = Schema([
            Session.self,
            UserSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        // Populate only with settings, no sessions
        let settings = UserSettings()
        container.mainContext.insert(settings)
        
        return container
    }
    
    static func generateMockSessions(count: Int = 0) -> [Session] {
        var sessions: [Session] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Base coordinate 41.256230458882776, -95.941144222386
        let baseLat = 41.256230458882776
        let baseLon = -95.941144222386
        
        // Generate data over 4 years (approx 1460 days) to test all chart ranges
        // Strategy:
        // - Last 60 days: High frequency (near daily)
        // - 60 days to 1 year: Medium frequency (2-3 times a week)
        // - 1 year to 4 years: Low frequency (once a week or so)
        
        let totalDays = 365 * 4 + 60 
        
        for dayOffset in 0..<totalDays {
            // Determine probability based on how recent the day is
            let probability: Double
            if dayOffset < 60 {
                probability = 0.8 // 80% chance of working on a recent day
            } else if dayOffset < 365 {
                probability = 0.4 // 40% chance
            } else {
                probability = 0.1 // 10% chance
            }
            
            if Double.random(in: 0...1) < probability {
                // Generate a session for this day
                // To simulate realistic times, subtract days from now
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
                
                // Random start time between 8 AM and 8 PM
                let hourOffset = Double.random(in: 8...20) * 3600
                let start = calendar.startOfDay(for: date).addingTimeInterval(hourOffset)
                
                let duration = Double.random(in: 1800...28800) // 30 mins to 8 hours
                let end = start.addingTimeInterval(duration)
                
                // Create a mock user settings for this session
                let mockSettings = UserSettings()
                // Slowly increase wage over time (inflation/raises) ?? No, just random variation
                mockSettings.hourlyWage = Double.random(in: 18.0...35.0).rounded(to: 2)
                mockSettings.mpg = Double.random(in: 22.0...32.0).rounded(to: 1)
                
                let session = Session(startTimestamp: start, userSettings: mockSettings)
                session.endTimestamp = end
                
                // Random stats scaled by duration
                let durationHours = duration / 3600.0
                session.deliveriesCount = Int(Double.random(in: 1.5...4.0) * durationHours)
                session.gpsDistanceMeters = Double.random(in: 10000...25000) * durationHours // 10-25km per hour
                
                // Random tips
                let tipCount = Int(Double(session.deliveriesCount) * 0.8) // 80% tip rate
                for _ in 0..<tipCount {
                    let randomTip = Decimal(Double.random(in: 2.0...20.0)).rounded(2)
                    let cents = Decimal(Double.random(in: 0.01...0.99))
                    session.tips.append(randomTip + cents)
                }
                
                // Generate a random route (simplified)
                session.route = generateRoute(
                    startLat: baseLat + Double.random(in: -0.05...0.05),
                    startLon: baseLon + Double.random(in: -0.05...0.05),
                    points: 5 // Keep points low for memory in preview
                )
                
                // Force calculations
                _ = session.grossEarnings
                
                sessions.append(session)
            }
        }
        
        return sessions.sorted { $0.startTimestamp > $1.startTimestamp } // Return sorted
    }
    
    static func generateRoute(startLat: Double, startLon: Double, points: Int) -> [LocationData] {
        var route: [LocationData] = []
        var currentLat = startLat
        var currentLon = startLon
        
        for i in 0..<points {
            let loc = LocationData(
                latitude: currentLat,
                longitude: currentLon,
                timestamp: Date().addingTimeInterval(Double(i) * 60), // 1 min apart
                speed: Double.random(in: 10...60), // Random speed mph
                altitude: 0
            )
            route.append(loc)
            
            // Move randomly
            currentLat += Double.random(in: -0.002...0.002)
            currentLon += Double.random(in: -0.002...0.002)
        }
        
        return route
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var result = self
        var localSelf = self
        NSDecimalRound(&result, &localSelf, scale, .plain)
        return result
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}



extension WeatherUIModel {
    static let mock = WeatherUIModel(
        temperature: "72°",
        conditionIcon: "sun.max.fill",
        conditionDescription: "Sunny",
        apparentTemperature: "75°",
        wind: "8 mph NW",
        uvIndex: "6 (High)",
        humidity: "42%",
        visibility: "10 mi",
        pressure: "29.92 inHg",
        cloudCover: "12%",
        highTemperature: "78°",
        lowTemperature: "65°",
        precipitationText: "No precipitation expected",
        precipitationIcon: "sun.min.fill",
        precipitationChance: "0%",
        // Safety Defaults
        isLowVisibility: false,
        windSpeed: "8 mph",
        windGust: "12 mph",
        isHighWind: false,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: false,
        officialAlerts: [],
        precipitationIntensityForecast: [],
        locationTimeZone: .current
    )
    
    static let rainTonight = WeatherUIModel(
        temperature: "68°",
        conditionIcon: "cloud.moon.rain.fill",
        conditionDescription: "Rain",
        apparentTemperature: "65°",
        wind: "12 mph NW",
        uvIndex: "0 (Low)",
        humidity: "85%",
        visibility: "4 mi",
        pressure: "29.80 inHg",
        cloudCover: "90%",
        highTemperature: "72°",
        lowTemperature: "60°",
        precipitationText: "Rain tonight at 8 PM",
        precipitationIcon: "cloud.rain.fill",
        precipitationChance: "80%",
        isLowVisibility: false,
        windSpeed: "12 mph",
        windGust: "15 mph",
        isHighWind: false,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: true,
        officialAlerts: [
            WeatherAlertModel(
                summary: "Flood Watch",
                detailsURL: URL(string: "https://weather.apple.com")!,
                source: "National Weather Service",
                severity: "Moderate"
            )
        ],
        precipitationIntensityForecast: [0.1, 0.4, 0.8, 0.95, 0.9, 0.5].enumerated().map { index, intensity in
            PrecipDataPoint(date: Date().addingTimeInterval(Double(index) * 3600), intensity: intensity)
        },
        locationTimeZone: .current
    )
    
    static let rainInTwoDays = WeatherUIModel(
        temperature: "70°",
        conditionIcon: "cloud.sun.fill",
        conditionDescription: "Partly Cloudy",
        apparentTemperature: "72°",
        wind: "5 mph W",
        uvIndex: "4 (Moderate)",
        humidity: "45%",
        visibility: "10 mi",
        pressure: "30.05 inHg",
        cloudCover: "20%",
        highTemperature: "75°",
        lowTemperature: "58°",
        precipitationText: "Rain in 2 days",
        precipitationIcon: "cloud.rain.fill",
        precipitationChance: "60%",
        isLowVisibility: false,
        windSpeed: "5 mph",
        windGust: "8 mph",
        isHighWind: false,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: true,
        officialAlerts: [],
        precipitationIntensityForecast: [0, 0, 0.2, 0.5, 0.3, 0.1].enumerated().map { index, intensity in
            PrecipDataPoint(date: Date().addingTimeInterval(Double(index) * 3600), intensity: intensity)
        },
        locationTimeZone: .current
    )
    
    // Safety Mocks
    
    static let lowVisibility = WeatherUIModel(
        temperature: "45°",
        conditionIcon: "cloud.fog.fill",
        conditionDescription: "Fog",
        apparentTemperature: "42°",
        wind: "3 mph N",
        uvIndex: "1 (Low)",
        humidity: "95%",
        visibility: "0.2 mi",
        pressure: "29.92 inHg",
        cloudCover: "100%",
        highTemperature: "50°",
        lowTemperature: "40°",
        precipitationText: "No precip",
        precipitationIcon: "cloud.fog.fill",
        precipitationChance: "0%",
        isLowVisibility: true,
        windSpeed: "3 mph",
        windGust: "4 mph",
        isHighWind: false,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: false,
        officialAlerts: [],
        precipitationIntensityForecast: [],
        locationTimeZone: .current
    )
    
    static let highWind = WeatherUIModel(
        temperature: "55°",
        conditionIcon: "wind",
        conditionDescription: "Windy",
        apparentTemperature: "50°",
        wind: "35 mph W",
        uvIndex: "2 (Low)",
        humidity: "40%",
        visibility: "10 mi",
        pressure: "29.50 inHg",
        cloudCover: "80%",
        highTemperature: "60°",
        lowTemperature: "50°",
        precipitationText: "No precip",
        precipitationIcon: "wind",
        precipitationChance: "0%",
        isLowVisibility: false,
        windSpeed: "35 mph",
        windGust: "45 mph",
        isHighWind: true,
        extremeColdAlert: false,
        extremeHeatAlert: false,
        isPrecipitationAlert: false,
        officialAlerts: [
            WeatherAlertModel(
                summary: "High Wind Warning",
                detailsURL: URL(string: "https://weather.apple.com")!,
                source: "National Weather Service",
                severity: "Extreme"
            )
        ],
        precipitationIntensityForecast: [],
        locationTimeZone: .current
    )
    
    static let extremeCold = WeatherUIModel(
        temperature: "-15°",
        conditionIcon: "thermometer.snowflake",
        conditionDescription: "Frigid",
        apparentTemperature: "-25°",
        wind: "10 mph N",
        uvIndex: "1 (Low)",
        humidity: "30%",
        visibility: "8 mi",
        pressure: "30.50 inHg",
        cloudCover: "20%",
        highTemperature: "-5°",
        lowTemperature: "-20°",
        precipitationText: "No precip",
        precipitationIcon: "sun.max.fill",
        precipitationChance: "0%",
        isLowVisibility: false,
        windSpeed: "10 mph",
        windGust: "15 mph",
        isHighWind: false,
        extremeColdAlert: true,
        extremeHeatAlert: false,
        isPrecipitationAlert: false,
        officialAlerts: [],
        precipitationIntensityForecast: [],
        locationTimeZone: .current
    )
    
    static let criticalAll = WeatherUIModel(
        temperature: "-15°",
        conditionIcon: "wind.snow",
        conditionDescription: "Blizzard",
        apparentTemperature: "-35°",
        wind: "45 mph N",
        uvIndex: "0 (Low)",
        humidity: "90%",
        visibility: "0.1 mi",
        pressure: "29.10 inHg",
        cloudCover: "100%",
        highTemperature: "-5°",
        lowTemperature: "-20°",
        precipitationText: "Heavy snow",
        precipitationIcon: "snowflake",
        precipitationChance: "100%",
        isLowVisibility: true,
        windSpeed: "45 mph",
        windGust: "60 mph",
        isHighWind: true,
        extremeColdAlert: true,
        extremeHeatAlert: false,
        isPrecipitationAlert: true,
        officialAlerts: [
            WeatherAlertModel(
                summary: "Blizzard Warning",
                detailsURL: URL(string: "https://weather.apple.com")!,
                source: "National Weather Service",
                severity: "Extreme"
            ),
            WeatherAlertModel(
                summary: "Wind Chill Warning",
                detailsURL: URL(string: "https://weather.apple.com")!,
                source: "National Weather Service",
                severity: "Extreme"
            )
        ],
        precipitationIntensityForecast: [0.5, 0.75, 0.95, 1.0, 0.85, 0.7].enumerated().map { index, intensity in
            PrecipDataPoint(date: Date().addingTimeInterval(Double(index) * 3600), intensity: intensity)
        },
        locationTimeZone: .current
    )
}

extension PreviewHelper {
    static func configureWeatherPreview(with state: WeatherUIModel) {
        WeatherManager.shared.isPreview = true
        WeatherManager.shared.mockData = state
        WeatherManager.shared.ui = state
    }
    
    // Overload for default mock to avoid isolation issues with default arguments
    static func configureWeatherPreview() {
        configureWeatherPreview(with: .mock)
    }
    
    // MARK: - Gas Preview Configuration
    static func configureGasPreview(stations: [GasStation]? = nil, isLoading: Bool = false, error: String? = nil) {
        let fetcher = GasPriceFetcher.shared
        fetcher.stations = stations ?? mockGasStations
        fetcher.isLoading = isLoading
        fetcher.lastError = error
        fetcher.lastFetchTime = (stations ?? mockGasStations).isEmpty ? nil : Date()
    }
    
    static func configureDashboardPreview(weather: WeatherUIModel = .mock, gasStations: [GasStation]? = nil) {
        configureWeatherPreview(with: weather)
        configureGasPreview(stations: gasStations)
    }
    
    nonisolated static var mockGasStations: [GasStation] {
        [
            GasStation(
                id: "1",
                name: "Shell",
                address: StationAddress(
                    line1: "123 Main St",
                    locality: "Omaha",
                    postalCode: "68101",
                    region: "NE",
                    country: "USA"
                ),
                brands: [
                    StationBrand(
                        name: "Shell",
                        imageUrl: "https://www.gasbuddy.com/assets/images/logos/stations/svg/shell.svg"
                    )
                ],
                prices: [
                    PriceReport(
                        fuelProduct: "regular_gas",
                        credit: FuelPrice(
                            price: 3.45,
                            formattedPrice: "$3.45",
                            postedTime: Date().addingTimeInterval(-3600).ISO8601Format()
                        ),
                        cash: FuelPrice(
                            price: 3.35,
                            formattedPrice: "$3.35",
                            postedTime: Date().addingTimeInterval(-3600).ISO8601Format()
                        )
                    )
                ],
                latitude: 41.2565,
                longitude: -95.9345,
                fuels: ["regular_gas", "midgrade", "premium", "diesel"],
                starRating: 4.2
            ),
            GasStation(
                id: "2",
                name: "QuikTrip",
                address: StationAddress(
                    line1: "456 Dodge St",
                    locality: "Omaha",
                    postalCode: "68102",
                    region: "NE",
                    country: "USA"
                ),
                brands: [
                    StationBrand(
                        name: "QuikTrip",
                        imageUrl: "https://www.gasbuddy.com/assets/images/logos/stations/svg/quiktrip.svg"
                    )
                ],
                prices: [
                    PriceReport(
                        fuelProduct: "regular_gas",
                        credit: FuelPrice(
                            price: 3.39,
                            formattedPrice: "$3.39",
                            postedTime: Date().addingTimeInterval(-1800).ISO8601Format()
                        ),
                        cash: FuelPrice(
                            price: 3.39,
                            formattedPrice: "$3.39",
                            postedTime: Date().addingTimeInterval(-1800).ISO8601Format()
                        )
                    )
                ],
                latitude: 41.2612,
                longitude: -95.9412,
                fuels: ["regular_gas", "midgrade", "premium"],
                starRating: 4.5
            ),
            GasStation(
                id: "3",
                name: "Casey's General Store",
                address: StationAddress(
                    line1: "789 Farnam St",
                    locality: "Omaha",
                    postalCode: "68102",
                    region: "NE",
                    country: "USA"
                ),
                brands: [
                    StationBrand(
                        name: "Casey's",
                        imageUrl: "https://www.gasbuddy.com/assets/images/logos/stations/svg/caseys.svg"
                    )
                ],
                prices: [
                    PriceReport(
                        fuelProduct: "regular_gas",
                        credit: FuelPrice(
                            price: 3.52,
                            formattedPrice: "$3.52",
                            postedTime: Date().addingTimeInterval(-7200).ISO8601Format()
                        ),
                        cash: FuelPrice(
                            price: 3.52,
                            formattedPrice: "$3.52",
                            postedTime: Date().addingTimeInterval(-7200).ISO8601Format()
                        )
                    )
                ],
                latitude: 41.2580,
                longitude: -95.9380,
                fuels: ["regular_gas", "midgrade", "premium", "diesel"],
                starRating: 3.8
            ),
            GasStation(
                id: "4",
                name: "BP",
                address: StationAddress(
                    line1: "321 Pacific St",
                    locality: "Omaha",
                    postalCode: "68108",
                    region: "NE",
                    country: "USA"
                ),
                brands: [
                    StationBrand(
                        name: "BP",
                        imageUrl: "https://www.gasbuddy.com/assets/images/logos/stations/svg/bp.svg"
                    )
                ],
                prices: [
                    PriceReport(
                        fuelProduct: "regular_gas",
                        credit: FuelPrice(
                            price: 3.47,
                            formattedPrice: "$3.47",
                            postedTime: Date().addingTimeInterval(-5400).ISO8601Format()
                        ),
                        cash: FuelPrice(
                            price: 3.42,
                            formattedPrice: "$3.42",
                            postedTime: Date().addingTimeInterval(-5400).ISO8601Format()
                        )
                    )
                ],
                latitude: 41.2590,
                longitude: -95.9450,
                fuels: ["regular_gas", "premium"],
                starRating: 4.0
            ),
            GasStation(
                id: "5",
                name: "Costco Gas",
                address: StationAddress(
                    line1: "555 S 168th St",
                    locality: "Omaha",
                    postalCode: "68118",
                    region: "NE",
                    country: "USA"
                ),
                brands: [
                    StationBrand(
                        name: "Costco",
                        imageUrl: "https://www.gasbuddy.com/assets/images/logos/stations/svg/costco.svg"
                    )
                ],
                prices: [
                    PriceReport(
                        fuelProduct: "regular_gas",
                        credit: FuelPrice(
                            price: 3.29,
                            formattedPrice: "$3.29",
                            postedTime: Date().addingTimeInterval(-600).ISO8601Format()
                        ),
                        cash: FuelPrice(
                            price: 3.29,
                            formattedPrice: "$3.29",
                            postedTime: Date().addingTimeInterval(-600).ISO8601Format()
                        )
                    )
                ],
                latitude: 41.2555,
                longitude: -95.9500,
                fuels: ["regular_gas", "premium"],
                starRating: 4.7
            )
        ]
    }
}
