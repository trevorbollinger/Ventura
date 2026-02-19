//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI
import CoreLocation

enum GasSortOption: String, CaseIterable, Identifiable {
    case price = "Price"
    case distance = "Distance"
    var id: String { self.rawValue }
}

struct GasPricesCard: View {
    let stations: [GasStation]
    let isLoading: Bool
    let lastFetchTime: Date?
    let userLocation: CLLocation?
    let error: String?
    let onRetry: () -> Void
    
    @State private var sortOption: GasSortOption = .price
    @State private var showingAll: Bool = false
    
    @ScaledMetric(relativeTo: .caption) private var smallIconSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var mediumIconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var priceSize: CGFloat = 18
    @ScaledMetric(relativeTo: .headline) private var pumpIconSize: CGFloat = 24
    
    private func timeString(updateDate: Date) -> String {
        guard let lastTime = lastFetchTime else { return "Cheapest regular unleaded nearby" }
        
        let elapsed = updateDate.timeIntervalSince(lastTime)
        if elapsed < 60 {
            return "Updated just now"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Updated \(formatter.localizedString(for: lastTime, relativeTo: updateDate))"
    }
    
    @State private var sortedStations: [GasStation] = []
    
    // Throttle location updates for sorting
    @State private var lastSortLocation: CLLocation?
    private let sortDistanceThreshold: CLLocationDistance = 500 // meters

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .center) {
                Image(systemName: "fuelpump.fill")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby Gas Prices")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        TimelineView(.periodic(from: .now, by: 10)) { context in
                            Text(isLoading ? "Searching for the best prices..." : timeString(updateDate: context.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Sort Picker
                    if !isLoading && !stations.isEmpty {
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(GasSortOption.allCases) { option in
                                    Label(option.rawValue, systemImage: option == .price ? "dollarsign.circle" : "location.circle")
                                        .tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortOption.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: smallIconSize, weight: .bold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if !isLoading {
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: mediumIconSize, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            VStack(spacing: 0) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                        Divider().background(Color.gray.opacity(0.2))
                    }
                } else if error != nil {
                    VStack(spacing: 8) {
                        Text("Couldn't load prices")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button("Try Again", action: onRetry)
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if stations.isEmpty {
                    Text("No gas prices found in your immediate area.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    let displayCount = showingAll ? min(10, sortedStations.count) : min(3, sortedStations.count)
                    
                    ForEach(sortedStations.prefix(displayCount)) { station in
                        stationRow(station)
                        
                        if station.id != sortedStations.prefix(displayCount).last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                        }
                    }
                    
                    // Show More / Show Less Button
                    if sortedStations.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAll.toggle()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(showingAll ? "Show Less" : "Show More")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Image(systemName: showingAll ? "chevron.up" : "chevron.down")
                                    .font(.system(size: smallIconSize, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(20)
//        .overlay(
//            RoundedRectangle(cornerRadius: 20)
//                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        .onChange(of: stations) { _, _ in
            updateSortedStations()
        }
        .onChange(of: sortOption) { _, _ in
            updateSortedStations()
        }
        .onChange(of: userLocation) { _, newLocation in
             guard let newLocation else { return }
             if sortOption == .distance {
                 if let lastLoc = lastSortLocation {
                     let distance = newLocation.distance(from: lastLoc)
                     if distance > sortDistanceThreshold {
                         updateSortedStations()
                     }
                 } else {
                     updateSortedStations()
                 }
             }
        }
        .onAppear {
            updateSortedStations()
        }
    }
    
    private func updateSortedStations() {
        // Run sorting on main thread (throttled by onChange)
        // For <20 stations, this is negligible loop cost compared to body redrawing
        
        var newSorted: [GasStation] = []
        
        switch sortOption {
        case .price:
            newSorted = stations.sorted {
                ($0.regularPrice ?? Double.infinity) < ($1.regularPrice ?? Double.infinity)
            }
        case .distance:
            if let userLoc = userLocation {
                newSorted = stations.sorted { s1, s2 in
                    let d1 = s1.distance(from: userLoc)
                    let d2 = s2.distance(from: userLoc)
                    return d1 < d2
                }
                lastSortLocation = userLoc
            } else {
                newSorted = stations
            }
        }
        
        self.sortedStations = newSorted
    }

    private func stationRow(_ station: GasStation) -> some View {
        HStack(spacing: 12) {
            // Brand Icon
            ZStack {
                if let url = station.brandLogoUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(Color.gray.opacity(0.2))
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(6)
                        case .failure:
                            Image(systemName: "fuelpump")
                                .font(.system(size: mediumIconSize))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "fuelpump")
                        .font(.system(size: mediumIconSize))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.05))
            .clipShape(Circle())
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name ?? "Gas Station")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(station.formattedAddress)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Price
            VStack(alignment: .trailing, spacing: 2) {
                if let price = station.regularPrice, price > 0 {
                    Text(String(format: "$%.2f", price))
                        .font(.system(size: priceSize, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                } else {
                    Text("--")
                        .font(.system(size: priceSize, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Navigate Button
            Button {
                // Use 'q' (query) with name and 'll' (lat/long) to open the Apple Maps place page
                // This shows reviews, photos, hours, and has a Directions button
                if let lat = station.latitude, let lon = station.longitude {
                    let placeName = (station.name ?? "Gas Station").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Gas+Station"
                    let urlString = "maps://?q=\(placeName)&ll=\(lat),\(lon)"
                    
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    // Fallback to address-based search if no coordinates
                    let encodedAddress = station.formattedAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let urlString = "maps://?q=\(encodedAddress)"
                    
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                }
            } label: {
                Image(systemName: "arrow.trianglehead.turn.up.right.circle.fill")
                    .font(.system(size: mediumIconSize, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }
}


private struct SkeletonRow: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(opacity))
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(opacity))
                    .frame(width: 120, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(opacity))
                    .frame(width: 180, height: 10)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(opacity))
                .frame(width: 50, height: 20)
        }
        .padding(.vertical, 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.1
            }
        }
    }
}

#Preview {
    PreviewHelper.configureGasPreview()
    return ZStack {
        Color.black.ignoresSafeArea()
        GasPricesCard(
            stations: PreviewHelper.mockGasStations,
            isLoading: false,
            lastFetchTime: Date(),
            userLocation: CLLocation(latitude: 41.2565, longitude: -95.9345),
            error: nil,
            onRetry: {}
        )
        .padding()
    }
}

#Preview("Loading") {
    PreviewHelper.configureGasPreview(isLoading: true)
    return ZStack {
        Color.black.ignoresSafeArea()
        GasPricesCard(
            stations: [],
            isLoading: true,
            lastFetchTime: nil,
            userLocation: nil,
            error: nil,
            onRetry: {}
        )
        .padding()
    }
}

#Preview("Error") {
    PreviewHelper.configureGasPreview(stations: [], error: "Connection failed")
    return ZStack {
        Color.black.ignoresSafeArea()
        GasPricesCard(
            stations: [],
            isLoading: false,
            lastFetchTime: nil,
            userLocation: nil,
            error: "Connection failed",
            onRetry: {}
        )
        .padding()
    }
}
