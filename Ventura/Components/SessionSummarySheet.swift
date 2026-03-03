//
//  SessionSummarySheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import SwiftUI
import MapKit
import SwiftData

struct SessionSummarySheet: View {
    @Bindable var session: Session
    @Environment(\.dismiss) var dismiss

    @State private var showAddTipSheet = false
    @State private var editingTipIndex: Int? = nil
    var isPresentedAsSheet: Bool = false
    
    @Query private var allSettings: [UserSettings]
    private var settings: UserSettings { allSettings.first ?? UserSettings() }
    
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoadingRoute = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Stats
                headerSection
                
                // Earnings Breakdown
                earningsSection
                
                // Map Section
                mapSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(isPresentedAsSheet ? .visible : .hidden)
       
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isPresentedAsSheet {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showAddTipSheet) {
            LogDeliverySheet { amount, countAsDelivery in
                session.tips.append(amount)
                if countAsDelivery {
                    session.deliveriesCount += 1
                }
            }
        }
        .sheet(item: Binding(
            get: { editingTipIndex.map { IdentifiableInt(id: $0) } },
            set: { editingTipIndex = $0?.id }
        )) { item in
            LogDeliverySheet(initialValue: session.tips[item.id], isEditing: true) { amount, _ in
                if session.tips.indices.contains(item.id) {
                    session.tips[item.id] = amount
                }
            }
        }
        .task {
            // Asynchronously fetch the route to avoid SwiftData deserialization lag on the main thread
            let sessionID = session.id
            let container = session.modelContext?.container
            
            guard let container = container else {
                isLoadingRoute = false
                return
            }
            
            Task.detached(priority: .background) {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { $0.id == sessionID }
                )
                
                if let bgSession = try? context.fetch(descriptor).first {
                    // Extract just the raw data we need to construct coords to avoid keeping full Objects alive
                    let latitudes = bgSession.route.map { $0.latitude }
                    let longitudes = bgSession.route.map { $0.longitude }
                    
                    var mutableCoords: [CLLocationCoordinate2D] = []
                    mutableCoords.reserveCapacity(latitudes.count)
                    for i in 0..<latitudes.count {
                        mutableCoords.append(CLLocationCoordinate2D(latitude: latitudes[i], longitude: longitudes[i]))
                    }
                    let coords = mutableCoords
                    
                    await MainActor.run {
                        self.routeCoordinates = coords
                        self.isLoadingRoute = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingRoute = false
                    }
                }
            }
        }
    }
    
    // MARK: - Extracted Sections
    
    @ViewBuilder
    private var headerSection: some View {
        SessionStatsCard(session: session, settings: settings, editable: true)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var earningsSection: some View {
        SummarySection(title: "Earnings", icon: "dollarsign.circle.fill") {
            VStack(spacing: 20) {
                // Income
                if session.wageTypeRaw == "Split" {
                    if session.drivingPay > 0 {
                        EarningsRow(label: "Driving Pay", value: session.drivingPay, isExpense: false, iconColor: Color("WageColor"))
                    }
                    if session.homePay > 0 {
                        EarningsRow(label: "In-Store Pay", value: session.homePay, isExpense: false, iconColor: Color("PassiveColor"))
                    }
                } else if session.totalHourlyPay > 0 {
                    EarningsRow(label: "Hourly Pay", value: session.totalHourlyPay, isExpense: false, iconColor: Color("WageColor"))
                }
                
                if session.totalTips > 0 {
                    EarningsRow(label: "Tips", value: session.totalTips, isExpense: false, iconColor: Color("TipsColor"))
                }
                
                if session.totalMileageReimbursement > 0 {
                    EarningsRow(label: "Mileage Pay", value: session.totalMileageReimbursement, isExpense: false, iconColor: Color("MileageColor"))
                }
                
                if session.totalDeliveryRates > 0 {
                    EarningsRow(label: "Delivery Fees", value: session.totalDeliveryRates, isExpense: false, iconColor: Color("MileageColor"))
                }
                
                // Expenses
                if session.fuelExpense > 0 {
                    EarningsRow(label: "Fuel Cost", value: session.fuelExpense, isExpense: true, iconColor: Color("FuelColor"))
                }
                
                if session.maintenanceExpense > 0 {
                    EarningsRow(label: "Maintenance", value: session.maintenanceExpense, isExpense: true, iconColor: Color("MaintenanceColor"))
                }
                
                Divider()
                
                // Net Profit
                HStack {
                    Text("Net Profit")
                        .font(.headline.bold())
                    Spacer()
                    Text(session.netProfit.formatted(.currency(code: "USD")))
                        .font(.headline.bold())
                }
                
                // Tip Actions
                Button {
                    showAddTipSheet = true
                } label: {
                    Label("Add Tip", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if !session.tips.isEmpty {
                    DisclosureGroup("Manage Tips") {
                        VStack(spacing: 12) {
                            ForEach(session.tips.indices, id: \.self) { index in
                                HStack {
                                    Text("Tip #\(index + 1)").foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        editingTipIndex = index
                                    } label: {
                                        Text(session.tips[index].formatted(.currency(code: "USD")))
                                            .font(.body.monospacedDigit())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Button(role: .destructive) {
                                        session.tips.remove(at: index)
                                        session.deliveriesCount = max(0, session.deliveriesCount - 1)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mapSection: some View {
        SummarySection(title: "Route Map", icon: "map.fill") {
            if isLoadingRoute {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding()
            } else if routeCoordinates.isEmpty {
                Text("No location data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding()
            } else {
                NavigationLink(destination: RouteMapView(session: session)) {
                    ZStack(alignment: .bottomTrailing) {
                        StaticRouteMap(
                            routeCoordinates: routeCoordinates,
                            session: session
                        )
                        .disabled(true)
                        .frame(height: 200)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                

            }
        }
    }
}

// MARK: - Subcomponents

struct EarningsRow: View {
    let label: String
    let value: Decimal
    let isExpense: Bool
    var iconColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(isExpense ? "-" : "+")
                .font(.caption.bold())
                .foregroundStyle(iconColor ?? (isExpense ? Color("MaintenanceColor") : Color("TipsColor")))
            Text(value.formatted(.currency(code: "USD")))
                .fontWeight(.semibold)
                .foregroundStyle(iconColor ?? (isExpense ? Color("MaintenanceColor") : Color("TipsColor")))
            
        }
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            content
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct IdentifiableInt: Identifiable {
    let id: Int
}

struct StaticRouteMap: View, Equatable {
    let routeCoordinates: [CLLocationCoordinate2D]
    let session: Session // Passed but not actively watched in Equatable

    static func == (lhs: StaticRouteMap, rhs: StaticRouteMap) -> Bool {
        // Only redraw if the coordinate array changes length or the first point changes.
        // Extremely fast equatable check compared to a full Array diff
        return lhs.routeCoordinates.count == rhs.routeCoordinates.count &&
               lhs.routeCoordinates.first?.latitude == rhs.routeCoordinates.first?.latitude
    }

    var body: some View {
        Map {
            MapPolyline(coordinates: routeCoordinates).stroke(.blue, lineWidth: 3)

            if let first = routeCoordinates.first {
                Marker("Start", coordinate: first).tint(.green)
            }
            if let last = routeCoordinates.last {
                Marker("End", coordinate: last).tint(.red)
            }
        }
    }
}
