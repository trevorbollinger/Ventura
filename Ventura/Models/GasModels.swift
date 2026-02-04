import Foundation
import CoreLocation

// MARK: - GasData Response Root
struct GasDataResponse: Codable {
    let data: GasDataData
}

struct GasDataData: Codable {
    let locationBySearchTerm: GasLocation
}

struct GasLocation: Codable {
    let countryCode: String?
    let displayName: String?
    let latitude: Double?
    let longitude: Double?
    let regionCode: String?
    let stations: StationResults?
    let trends: [GasTrend]?
}

// MARK: - Stations
struct StationResults: Codable {
    let count: Int?
    let results: [GasStation]?
}

struct GasStation: Codable, Identifiable {
    let id: String
    let name: String?
    let address: StationAddress?
    let brands: [StationBrand]?
    let prices: [PriceReport]?
    // let distance: Double? // Causing decode errors (String vs Double), and unused in UI
    let latitude: Double?
    let longitude: Double?
    let fuels: [String]?
    let starRating: Double?
    
    // Convenience Accessors
    var formattedAddress: String {
        guard let addr = address else { return "" }
        return [addr.line1, addr.locality, addr.region].compactMap { $0 }.joined(separator: ", ")
    }
    
    var regularPrice: Double? {
        // Look for 'regular_gas' and get the credit price (usually the main one shown)
        // Adjust logic if cash/credit differs significantly or if you prefer cash price
        guard let report = prices?.first(where: { $0.fuelProduct == "regular_gas" }) else { return nil }
        return report.credit?.price
    }
    
    var brandLogoUrl: URL? {
        guard let urlString = brands?.first?.imageUrl else { return nil }
        return URL(string: urlString)
    }
    
    func distance(from userLocation: CLLocation) -> CLLocationDistance {
        guard let lat = latitude, let lon = longitude else { return .infinity }
        let stationLoc = CLLocation(latitude: lat, longitude: lon)
        return userLocation.distance(from: stationLoc)
    }
}

struct StationAddress: Codable {
    let line1: String?
    let locality: String?
    let postalCode: String?
    let region: String?
    let country: String?
}

struct StationBrand: Codable {
    let name: String?
    let imageUrl: String?
}

// MARK: - Prices
struct PriceReport: Codable {
    let fuelProduct: String? // e.g. "regular_gas", "diesel"
    let credit: FuelPrice?
    let cash: FuelPrice?
}

struct FuelPrice: Codable {
    let price: Double?
    let formattedPrice: String?
    let postedTime: String? // ISO date string likely
}

// MARK: - Trends
struct GasTrend: Codable {
    let areaName: String?
    let today: Double?
    let todayLow: Double?
    let trend: Double? // + or - indicating direction
}
