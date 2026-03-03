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

extension Array where Element == LocationData {
    /// Reduces the number of points in a route using the Douglas-Peucker algorithm,
    /// while maintaining the visual shape of the path.
    /// - Parameter epsilon: The maximum distance (in meters) a point can deviate from the simplified line to be removed.
    ///   A higher epsilon removes more points (rougher line), a lower epsilon keeps more points (smoother line).
    ///   Try 5.0 for a balance of high performance and good accuracy.
    func downsampled(epsilon: Double = 5.0) -> [LocationData] {
        return simplify(slice: self[...], epsilon: epsilon)
    }
    
    private func simplify(slice: ArraySlice<LocationData>, epsilon: Double) -> [LocationData] {
        guard slice.count > 2 else { return Array(slice) }
        
        var dmax: Double = 0
        var index: Int = slice.startIndex
        let end = slice.endIndex - 1
        
        let firstPos = slice[slice.startIndex]
        let lastPos = slice[end]
        
        for i in (slice.startIndex + 1)..<end {
            let d = perpendicularDistance(point: slice[i], lineStart: firstPos, lineEnd: lastPos)
            if d > dmax {
                index = i
                dmax = d
            }
        }
        
        if dmax > epsilon {
            var recResults1 = simplify(slice: slice[slice.startIndex...index], epsilon: epsilon)
            let recResults2 = simplify(slice: slice[index...end], epsilon: epsilon)
            recResults1.removeLast()
            return recResults1 + recResults2
        } else {
            return [slice[slice.startIndex], slice[end]]
        }
    }
    
    // Calculates approximate distance in meters from a point to a line segment
    private func perpendicularDistance(point: LocationData, lineStart: LocationData, lineEnd: LocationData) -> Double {
        let x0 = point.longitude, y0 = point.latitude
        let x1 = lineStart.longitude, y1 = lineStart.latitude
        let x2 = lineEnd.longitude, y2 = lineEnd.latitude
        
        let dx = x2 - x1
        let dy = y2 - y1
        let num = abs(dy * x0 - dx * y0 + x2 * y1 - y2 * x1)
        let den = sqrt(dy * dy + dx * dx)
        
        guard den != 0 else {
            return 0 // Start and end are the same point
        }
        
        // Approx conversion of degrees to meters (varies by latitude, but sufficient for local simplifications)
        // 1 degree is roughly 111,320 meters
        let distanceInDegrees = num / den
        return distanceInDegrees * 111320.0
    }
}
