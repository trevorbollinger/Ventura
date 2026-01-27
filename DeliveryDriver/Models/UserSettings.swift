//
//  UserSettings.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftData
import Foundation

@Model
final class UserSettings {
    var driverTypeRaw: String = "1099 Contractor"
    var mpg: Double = 24.0
    var hourlyWage: Double = 15.0
    var passiveWage: Double = 10.0
    var reimbursement: Double = 0.50
    var wageTypeRaw: String = "Hourly"
    var reimbursementTypeRaw: String = "Per Mile"
    
    init(driverType: DriverType = .contractor,
         mpg: Double = 24.0,
         hourlyWage: Double = 15.0,
         passiveWage: Double = 10.0,
         reimbursement: Double = 0.50,
         wageType: WageType = .hourly,
         reimbursementType: ReimbursementType = .perMile) {
        self.driverTypeRaw = driverType.rawValue
        self.mpg = mpg
        self.hourlyWage = hourlyWage
        self.passiveWage = passiveWage
        self.reimbursement = reimbursement
        self.wageTypeRaw = wageType.rawValue
        self.reimbursementTypeRaw = reimbursementType.rawValue
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
