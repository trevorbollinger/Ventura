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
         homeRadius: Double = 200.0) {
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
}
