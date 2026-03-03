//
//  UserSettings.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftData
import Foundation

@Model
final class UserSettings {
    var driverTypeRaw: String = "1099 Contractor"
    var mpg: Double = 24.0
    var hourlyWage: Double = 15.0   // Standard Hourly Rate
    var drivingWage: Double = 10.0  // Active Rate (Split Mode)
    var passiveWage: Double = 15.0  // Passive Rate (Split Mode)
    var reimbursement: Double = 0.50
    var fuelPrice: Double = 3.0 // Default to $3.00/gal
    var wageTypeRaw: String = "Hourly"
    var reimbursementTypeRaw: String = "Per Mile"
    var isDebugMode: Bool = false
    

    // Localization
    var currencyCode: String = "USD"
    var distanceUnitRaw: String = "mi"
    var primaryMetricRaw: String = "hourly"
    
    // Background Style
    var backgroundStyleRaw: String = "mesh"

    
    // Home Location
    var homeLatitude: Double?
    var homeLongitude: Double?
    var homeAddress: String?
    var homeName: String?
    var homeIcon: String?
    var homeRadius: Double = 200.0
    
    // Maintenance & Gas
    var includeMaintenance: Bool = false
    var maintenanceCostPerMile: Double = 0.10
    var includeGas: Bool = true

    // Display Preferences
    var showWeatherPill: Bool = true

    // Calendar
    var weekStartsOnRaw: String = "sunday"
    
    init(driverType: DriverType = .contractor,
         mpg: Double = 24.0,
         hourlyWage: Double = 15.0,
         drivingWage: Double = 10.0,
         passiveWage: Double = 15.0,
         reimbursement: Double = 0.50,
         fuelPrice: Double = 3.0,
         wageType: WageType = .hourly,
         reimbursementType: ReimbursementType = .perMile,
         isDebugMode: Bool = false,
         includeMaintenance: Bool = false,
         maintenanceCostPerMile: Double = 0.10,
         includeGas: Bool = true,
         homeLatitude: Double? = nil,
         homeLongitude: Double? = nil,
         homeAddress: String? = nil,
         homeName: String? = nil,
         homeIcon: String? = nil,
         homeRadius: Double = 200.0,
         currencyCode: String = "USD",
         distanceUnitRaw: String = "mi",
         backgroundStyle: BackgroundStyle = .mesh,
         showWeatherPill: Bool = true,
         weekStartDay: WeekStartDay = .sunday,
         primaryMetric: PrimaryMetric = .hourly) {
        self.driverTypeRaw = driverType.rawValue
        self.mpg = mpg
        self.hourlyWage = hourlyWage
        self.drivingWage = drivingWage
        self.passiveWage = passiveWage
        self.reimbursement = reimbursement
        self.fuelPrice = fuelPrice
        self.wageTypeRaw = wageType.rawValue
        self.reimbursementTypeRaw = reimbursementType.rawValue
        self.isDebugMode = isDebugMode
        self.includeMaintenance = includeMaintenance
        self.maintenanceCostPerMile = maintenanceCostPerMile
        self.includeGas = includeGas
        self.homeLatitude = homeLatitude
        self.homeLongitude = homeLongitude
        self.homeAddress = homeAddress
        self.homeName = homeName
        self.homeIcon = homeIcon
        self.homeRadius = homeRadius
        self.currencyCode = currencyCode
        self.distanceUnitRaw = distanceUnitRaw
        self.backgroundStyleRaw = backgroundStyle.rawValue
        self.showWeatherPill = showWeatherPill
        self.weekStartsOnRaw = weekStartDay.rawValue
        self.primaryMetricRaw = primaryMetric.rawValue
    }
}

enum WeekStartDay: String, CaseIterable, Identifiable {
    case sunday = "sunday"
    case saturday = "saturday"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .saturday: return "Saturday"
        }
    }

    /// The Calendar.firstWeekday value (1 = Sunday, 7 = Saturday)
    var calendarFirstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .saturday: return 7
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles = "mi"
    case kilometers = "km"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }
    
    var unit: UnitLength {
        switch self {
        case .miles: return .miles
        case .kilometers: return .kilometers
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case fahrenheit = "F"
    case celsius = "C"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .fahrenheit: return "Fahrenheit"
        case .celsius: return "Celsius"
        }
    }
    
    var unit: UnitTemperature {
        switch self {
        case .fahrenheit: return .fahrenheit
        case .celsius: return .celsius
        }
    }
}

extension UserSettings {
    var driverType: DriverType {
        get { DriverType(rawValue: driverTypeRaw) ?? .contractor }
        set { driverTypeRaw = newValue.rawValue }
    }
    
    var wageType: WageType {
        get { WageType(rawValue: wageTypeRaw) ?? .hourly }
        set { wageTypeRaw = newValue.rawValue }
    }
    
    var reimbursementType: ReimbursementType {
        get { ReimbursementType(rawValue: reimbursementTypeRaw) ?? .perMile }
        set { reimbursementTypeRaw = newValue.rawValue }
    }
    
    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
        set { distanceUnitRaw = newValue.rawValue }
    }
    
    var backgroundStyle: BackgroundStyle {
        get { BackgroundStyle(rawValue: backgroundStyleRaw) ?? .mesh }
        set { backgroundStyleRaw = newValue.rawValue }
    }

    var weekStartDay: WeekStartDay {
        get { WeekStartDay(rawValue: weekStartsOnRaw) ?? .sunday }
        set { weekStartsOnRaw = newValue.rawValue }
    }

    // MARK: - Display Helpers
    
    /// Convert miles to the user's current display unit
    func displayDistance(miles: Double) -> Double {
        if distanceUnit == .kilometers {
            return Measurement(value: miles, unit: UnitLength.miles).converted(to: .kilometers).value
        }
        return miles
    }
    
    /// Label for current distance unit (e.g., "mi" or "km")
    var distanceLabel: String {
        distanceUnit == .kilometers ? "km" : "mi"
    }
    
    /// Label for per-distance rate (e.g., "/mi" or "/km")
    var perDistanceLabel: String {
        distanceUnit == .kilometers ? "/km" : "/mi"
    }
    
    /// Convert per-mile value to per-current-unit value
    func displayPerDistance(perMile: Double) -> Double {
        if distanceUnit == .kilometers {
            // $/mile to $/km: divide by 1.60934 (fewer km per $ amount)
            return perMile / 1.60934
        }
        return perMile
    }
}

enum PrimaryMetric: String, CaseIterable, Identifiable {
    case hourly = "hourly"
    case perDistance = "perDistance"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .hourly: return "$/Hour"
        case .perDistance: return "$/Distance"
        }
    }
}

extension UserSettings {
    var primaryMetric: PrimaryMetric {
        get { PrimaryMetric(rawValue: primaryMetricRaw) ?? .hourly }
        set { primaryMetricRaw = newValue.rawValue }
    }
}
