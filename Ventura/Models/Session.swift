//
//  Session.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftData
import Foundation

@Model
final class Session {
    var id: UUID = UUID()
    var startTimestamp: Date = Date()
    var endTimestamp: Date?
    
    // --- Live Data ---
    var tips: [Decimal] = [] // Stores individual tips
    var deliveriesCount: Int = 0
    
    // --- Time Tracking ---
    var timeAtHome: Double = 0.0 // Seconds spent within home radius
    var timeAway: Double = 0.0   // Seconds spent away from home
    
    // --- Mileage ---
    var gpsDistanceMeters: Double = 0.0
    var manualStartOdometer: Double?
    var manualEndOdometer: Double?
    var route: [LocationData] = []
    
    // --- Settings Snapshot ---
    // These lock in the rates at the time of the session
    var hourlyWage: Double = 0.0
    var drivingWage: Double = 0.0
    var passiveWage: Double = 15.0 // Renamed/Adjusted if needed, keeping simple standard for now
    var perDeliveryRate: Double?
    var mileageReimbursementRate: Double = 0.0
    var vehicleMPG: Double = 0.0
    var fuelPrice: Double = 0.0
    var wageTypeRaw: String = "Hourly"
    var reimbursementTypeRaw: String = "Per Mile"
    
    // Localization Snapshot
    var currencyCode: String = "USD"
    
    // --- Pay Accumulators (Computed) ---
    // These are now derived dynamically from time buckets + rates
    
    var drivingPay: Decimal {
        let hours = Decimal(timeAway) / 3600
        return hours * Decimal(drivingWage)
    }
    
    var homePay: Decimal {
        let hours = Decimal(timeAtHome) / 3600
        return hours * Decimal(passiveWage)
    }
    
    // --- Maintenance & Gas Snapshot ---
    var includeMaintenance: Bool = false
    var maintenanceCostPerMile: Double = 0.0
    var includeGas: Bool = true
    
    init(startTimestamp: Date = Date(), 
         userSettings: UserSettings) {
        self.startTimestamp = startTimestamp
        
        // Snapshot ALL settings to preserve how earnings were calculated
        self.wageTypeRaw = userSettings.wageTypeRaw
        self.reimbursementTypeRaw = userSettings.reimbursementTypeRaw
        
        // Snapshot wage rates based on type
        if userSettings.wageType != .none {
            self.hourlyWage = userSettings.hourlyWage
            self.drivingWage = userSettings.drivingWage
            self.passiveWage = userSettings.passiveWage
        }
        
        // Snapshot reimbursement based on type
        if userSettings.reimbursementType == .perMile {
            self.mileageReimbursementRate = userSettings.reimbursement
        } else if userSettings.reimbursementType == .perDelivery {
            self.perDeliveryRate = userSettings.reimbursement
        }
        
        self.vehicleMPG = userSettings.mpg
        self.fuelPrice = userSettings.fuelPrice
        
        self.includeMaintenance = userSettings.includeMaintenance
        self.maintenanceCostPerMile = userSettings.maintenanceCostPerMile
        self.includeGas = userSettings.includeGas
        
        // Snapshot Localization (currency only - distance converts at display time)
        self.currencyCode = userSettings.currencyCode
    }
    
    // --- Computed Properties (The Logic) ---
    
    var durationInHours: Decimal {
        let end = endTimestamp ?? Date() // Use current time if active
        let seconds = end.timeIntervalSince(startTimestamp)
        return Decimal(seconds / 3600)
    }
    
    /// ALWAYS returns miles, regardless of user display preference. Used for internal calculations (Gas, MPG, etc).
    /// Views should use UserSettings.displayDistance(miles:) to convert for display.
    var totalMiles: Double {
        if let start = manualStartOdometer, let end = manualEndOdometer {
            // Manual odometer assumed to be in miles
            return end - start
        }
        return gpsDistanceMeters / 1609.34 // Meters to Miles
    }
    
    // --- Earnings Logic ---

    var totalHourlyPay: Decimal {
        switch wageTypeRaw {
        case "Split":
            return drivingPay + homePay
        case "Hourly":
            // Standard Hourly: Calculate dynamically based on perfect wall-clock time
            return durationInHours * Decimal(hourlyWage)
        case "None":
            return 0
        default:
            return 0
        }
    }
    
    var totalMileageReimbursement: Decimal {
        if reimbursementTypeRaw == "Per Mile" {
             return Decimal(mileageReimbursementRate) * Decimal(totalMiles)
        }
        return 0
    }
    
    var totalDeliveryRates: Decimal {
        if reimbursementTypeRaw == "Per Delivery" {
            return Decimal(perDeliveryRate ?? 0) * Decimal(deliveriesCount)
        }
        return 0
    }

    var totalTips: Decimal {
        tips.reduce(0, +)
    }
    
    
    var grossEarnings: Decimal {
        // Use the computed property to handle Split vs Hourly logic centrally
        let hourlyPay = totalHourlyPay 
        // These now internally check the reimbursement type, so we can just sum them
        let mileagePay = totalMileageReimbursement
        let flatRates = totalDeliveryRates
        
        let total = hourlyPay + mileagePay + totalTips + flatRates
        
        return total
    }

    func invalidateCache() {
        // Cache removed to prevent AttributeGraph cycles during view updates.
        // This method is now a no-op kept for API compatibility.
    }
    
    var fuelExpense: Decimal {
        guard includeGas else { return 0 }
        let gallonsUsed = Decimal(totalMiles) / Decimal(vehicleMPG)
        return gallonsUsed * Decimal(fuelPrice)
    }
    
    var maintenanceExpense: Decimal {
        guard includeMaintenance else { return 0 }
        return Decimal(totalMiles) * Decimal(maintenanceCostPerMile)
    }
    
    var netProfit: Decimal {
        return grossEarnings - fuelExpense - maintenanceExpense
    }
    
    var earningsPerHour: Decimal {
        guard durationInHours > 0 else { return 0 }
        let calculatedRate = netProfit / durationInHours
        
        // Safeguard: When not moving (no expenses), the rate should theoretically never be below the base wage.
        // Clamp to the lowest applicable wage to prevent startup glitches where it shows $7.99 instead of $10.00.
        if totalMiles == 0 {
            let baseWage: Double
            switch wageTypeRaw {
            case "Split":
                baseWage = min(drivingWage, passiveWage)
            case "Hourly":
                baseWage = hourlyWage
            default:
                baseWage = 0
            }
            return max(calculatedRate, Decimal(baseWage))
        }
        
        return calculatedRate
    }
    
    var netPerMile: Decimal {
        guard totalMiles > 0 else { return 0 }
        return netProfit / Decimal(totalMiles)
    }
    // netPerMile is canonical - views convert with UserSettings.displayPerDistance(perMile:)
    
    // MARK: - Session Combining Support
    
    /// Encapsulates all rate-related fields for easy comparison
    struct RateInfo: Equatable, Hashable {
        let hourlyWage: Double
        let passiveWage: Double
        let perDeliveryRate: Double?
        let mileageReimbursementRate: Double
        let vehicleMPG: Double
        let fuelPrice: Double
        let wageTypeRaw: String
        let reimbursementTypeRaw: String
        let includeMaintenance: Bool
        let maintenanceCostPerMile: Double
        let includeGas: Bool
    }
    
    /// Returns all rate-related information for this session
    var rateInfo: RateInfo {
        RateInfo(
            hourlyWage: hourlyWage,
            passiveWage: passiveWage,
            perDeliveryRate: perDeliveryRate,
            mileageReimbursementRate: mileageReimbursementRate,
            vehicleMPG: vehicleMPG,
            fuelPrice: fuelPrice,
            wageTypeRaw: wageTypeRaw,
            reimbursementTypeRaw: reimbursementTypeRaw,
            includeMaintenance: includeMaintenance,
            maintenanceCostPerMile: maintenanceCostPerMile,
            includeGas: includeGas
        )
    }
    
    /// Checks if this session has the same rates as another session
    func hasSameRates(as other: Session) -> Bool {
        return self.rateInfo == other.rateInfo
    }
    
    /// Returns a list of field names that differ from another session
    func ratesDifferingFrom(_ other: Session) -> [String] {
        var differences: [String] = []
        let thisRate = self.rateInfo
        let otherRate = other.rateInfo
        
        if thisRate.hourlyWage != otherRate.hourlyWage {
            differences.append("Hourly Wage")
        }
        if thisRate.passiveWage != otherRate.passiveWage {
            differences.append("Passive Wage")
        }
        if thisRate.perDeliveryRate != otherRate.perDeliveryRate {
            differences.append("Per Delivery Rate")
        }
        if thisRate.mileageReimbursementRate != otherRate.mileageReimbursementRate {
            differences.append("Mileage Rate")
        }
        if thisRate.vehicleMPG != otherRate.vehicleMPG {
            differences.append("Vehicle MPG")
        }
        if thisRate.fuelPrice != otherRate.fuelPrice {
            differences.append("Fuel Price")
        }
        if thisRate.wageTypeRaw != otherRate.wageTypeRaw {
            differences.append("Wage Type")
        }
        if thisRate.reimbursementTypeRaw != otherRate.reimbursementTypeRaw {
            differences.append("Reimbursement Type")
        }
        if thisRate.includeMaintenance != otherRate.includeMaintenance {
            differences.append("Include Maintenance")
        }
        if thisRate.maintenanceCostPerMile != otherRate.maintenanceCostPerMile {
            differences.append("Maintenance Cost")
        }
        if thisRate.includeGas != otherRate.includeGas {
            differences.append("Include Gas")
        }
        
        return differences
    }
    
    /// Updates this session's rates to match another session's rates
    func adoptRates(from other: Session) {
        self.hourlyWage = other.hourlyWage
        self.passiveWage = other.passiveWage
        self.perDeliveryRate = other.perDeliveryRate
        self.mileageReimbursementRate = other.mileageReimbursementRate
        self.vehicleMPG = other.vehicleMPG
        self.fuelPrice = other.fuelPrice
        self.wageTypeRaw = other.wageTypeRaw
        self.reimbursementTypeRaw = other.reimbursementTypeRaw
        self.includeMaintenance = other.includeMaintenance
        self.maintenanceCostPerMile = other.maintenanceCostPerMile
        self.includeGas = other.includeGas
        invalidateCache() // Recalculate earnings with new rates
    }

    func durationString(at date: Date = Date()) -> String {
        let end = endTimestamp ?? date
        let diff = max(0, end.timeIntervalSince(startTimestamp))
        return TimeFormatter.formatDuration(diff)
    }
}
