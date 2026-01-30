//
//  SharedTypes.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import Foundation

enum WageType: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case hourly = "Hourly"
    case split = "Split"
    
    var id: String { rawValue }
}

enum ReimbursementType: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case perMile = "Per Mile"
    case perDelivery = "Per Delivery"
    
    var id: String { rawValue }
}

enum DriverType: String, CaseIterable, Identifiable, Codable {
    case w2 = "W-2 Employee"
    case contractor = "1099 Contractor"
    case both = "Both"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .w2: return "Domino's, Jimmy John's, etc."
        case .contractor: return "DoorDash, Uber, etc."
        case .both: return "I do both!"
        }
    }
}

struct LocationData: Codable, Identifiable {
    var id: UUID = UUID()
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var speed: Double
    var altitude: Double
}
