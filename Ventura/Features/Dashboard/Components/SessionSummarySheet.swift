//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//


import SwiftUI
import MapKit

struct SessionSummarySheet: View {
    @Bindable var session: Session
    @Environment(\.dismiss) var dismiss

    @State private var showAddTipSheet = false
    @State private var saveTrigger = false

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 8) {
                        Text("Total Profit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .padding(.top, 20)

                        Text(
                            session.netProfit.formatted(.currency(code: "USD"))
                        )
                        .font(
                            .system(size: 54, weight: .black, design: .rounded)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())

                        // Quick Stats Grid
                        HStack(spacing: 40) {
                            QuickStat(label: "TIME", value: formattedDuration)
                            Divider()
                                .frame(height: 30)
                            QuickStat(
                                label: "TRIPS",
                                value: "\(session.deliveriesCount)"
                            )
                            Divider()
                                .frame(height: 30)
                            QuickStat(
                                label: "MILES",
                                value: String(
                                    format: "%.1f",
                                    session.totalMiles
                                )
                            )
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                    // Time Section
                    SummarySection(title: "Time", icon: "clock.fill") {
                        VStack(spacing: 16) {
                            DatePicker("Started", selection: startBinding)
                            DatePicker("Ended", selection: endBinding)
                            
                            Divider()
                            
                            HStack {
                                Text("Active (Away)")
                                Spacer()
                                Text(formatSeconds(session.timeAway))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Passive (At Home)")
                                Spacer()
                                Text(formatSeconds(session.timeAtHome))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Work Section
                    SummarySection(title: "Work", icon: "briefcase.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Deliveries")
                                Spacer()
                                Stepper(value: $session.deliveriesCount, in: 0...999) {
                                    Text("\(session.deliveriesCount)")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack {
                                Text("Distance")
                                Spacer()
                                Text(String(format: "%.1f mi", session.totalMiles))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Earnings Section
                    SummarySection(title: "Earnings", icon: "dollarsign.circle.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Hourly Pay")
                                Spacer()
                                Text(session.totalHourlyPay.formatted(.currency(code: "USD")))
                            }

                            HStack {
                                Text("Tips")
                                Spacer()
                                Text(session.totalTips.formatted(.currency(code: "USD")))
                            }

                            Button {
                                showAddTipSheet = true
                            } label: {
                                Label("Add Tip", systemImage: "plus.circle.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            HStack {
                                Text("Mileage Pay")
                                Spacer()
                                Text(session.totalMileageReimbursement.formatted(.currency(code: "USD")))
                            }
                            
                            if (session.perDeliveryRate ?? 0) > 0 {
                                HStack {
                                    Text("Delivery Fees")
                                    Spacer()
                                    Text(session.totalDeliveryRates.formatted(.currency(code: "USD")))
                                }
                            }
                        }
                    }

                    // Settings & Rates Section
                    SummarySection(title: "Rates & settings", icon: "slider.horizontal.3") {
                        VStack(spacing: 16) {
                            // Wage Section
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Wage Type", selection: $session.wageTypeRaw) {
                                    Text("Hourly").tag("Hourly")
                                    Text("Split").tag("Split")
                                    Text("None").tag("None")
                                }
                                .pickerStyle(.segmented)
                                
                                if session.wageTypeRaw == "Hourly" {
                                    EditableRateRow(label: "Hourly Wage", value: $session.hourlyWage)
                                } else if session.wageTypeRaw == "Split" {
                                    EditableRateRow(label: "Driving Wage", value: $session.drivingWage)
                                    EditableRateRow(label: "In-Store Wage", value: $session.passiveWage)
                                }
                            }
                            
                            Divider()
                            
                            // Reimbursement Section
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Reimbursement", selection: $session.reimbursementTypeRaw) {
                                    Text("Per Mile").tag("Per Mile")
                                    Text("Per Delivery").tag("Per Delivery")
                                    Text("None").tag("None")
                                }
                                .pickerStyle(.segmented)
                                
                                if session.reimbursementTypeRaw == "Per Mile" {
                                    EditableRateRow(label: "Mileage Rate", value: $session.mileageReimbursementRate)
                                } else if session.reimbursementTypeRaw == "Per Delivery" {
                                    EditableRateRow(label: "Per Delivery Fee", value: perDeliveryBinding)
                                }
                            }
                            
                            Divider()
                            
                            // Vehicle & Expenses
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Include Fuel Cost", isOn: $session.includeGas)
                                if session.includeGas {
                                    EditableRateRow(label: "Fuel Price", value: $session.fuelPrice)
                                    EditableRateRow(label: "Vehicle MPG", value: $session.vehicleMPG)
                                }
                                
                                Toggle("Include Maintenance", isOn: $session.includeMaintenance)
                                if session.includeMaintenance {
                                    EditableRateRow(label: "Maint. Rate / mi", value: $session.maintenanceCostPerMile)
                                }
                            }
                        }
                    }

                    // Map Section
                    SummarySection(title: "Route Map", icon: "map.fill") {
                        if session.route.isEmpty {
                            Text("No location data available")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ZStack(alignment: .bottomTrailing) {
                                Map {
                                    MapPolyline(coordinates: session.route.map {
                                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                    })
                                    .stroke(.blue, lineWidth: 3)

                                    if let first = session.route.first {
                                        Marker("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude))
                                            .tint(.green)
                                    }
                                    if let last = session.route.last {
                                        Marker("End", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                                            .tint(.red)
                                    }
                                }
                                .disabled(true)
                                .frame(height: 200)

                                // Expand Icon
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .background(
                                NavigationLink(destination: RouteMapView(session: session)) {
                                    EmptyView()
                                }
                                .opacity(0)
                            )
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.vertical)
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveTrigger.toggle()
                        dismiss()
                    }
                    .bold()
                    .sensoryFeedback(.success, trigger: saveTrigger)
                }
            }
        .sheet(isPresented: $showAddTipSheet) {
            TipEntrySheet { amount in
                session.tips.append(amount)
                session.invalidateCache()
            }
        }

    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let doubleHours = NSDecimalNumber(decimal: session.durationInHours)
            .doubleValue
        let h = Int(doubleHours)
        let m = Int((doubleHours - Double(h)) * 60)
        return String(format: "%d:%02d", h, m)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %dm", h, m)
    }

    // MARK: - Pay Recalculation Logic

    private var startBinding: Binding<Date> {
        Binding(
            get: { session.startTimestamp },
            set: { newDate in
                let oldDate = session.startTimestamp
                // If moving start time earlier -> adding time (positive duration change)
                // If moving start time later -> removing time (negative duration change)
                // Delta for duration = old - new 
                // Example: Old 1:00, New 12:00 -> Delta +1 hour
                let delta = oldDate.timeIntervalSince(newDate)
                
                session.startTimestamp = newDate
                
                 if session.wageTypeRaw == "Split" {
                    adjustSplitBuckets(by: delta)
                }
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { session.endTimestamp ?? Date() },
            set: { newDate in
                let oldDate = session.endTimestamp ?? Date()
                // If moving end time later -> adding time (positive duration change)
                // If moving end time earlier -> removing time (negative duration change)
                // Delta for duration = new - old
                let delta = newDate.timeIntervalSince(oldDate)
                
                session.endTimestamp = newDate
                
                if session.wageTypeRaw == "Split" {
                    adjustSplitBuckets(by: delta)
                }
            }
        )
    }

    private func adjustSplitBuckets(by seconds: TimeInterval) {
        let hours = Decimal(seconds) / 3600
        
        // If adding time, attribute to Passive (Home)
        if seconds > 0 {
            session.timeAtHome += seconds
            session.homePay += hours * Decimal(session.passiveWage)
        } else {
            // If removing time, remove from Passive first, then Active
            let removeSeconds = abs(seconds)
            
            if session.timeAtHome >= removeSeconds {
                session.timeAtHome -= removeSeconds
                session.homePay -= (Decimal(removeSeconds) / 3600) * Decimal(session.passiveWage)
            } else {
                // Remove all remaining passive
                let remainingToRemove = removeSeconds - session.timeAtHome
                
                // Remove the money associated with the passive time we are wiping
                let passiveMoneyToRemove = (Decimal(session.timeAtHome) / 3600) * Decimal(session.passiveWage)
                session.homePay -= passiveMoneyToRemove
                session.timeAtHome = 0
                
                // Remove remaining from Active
                session.timeAway -= remainingToRemove
                let activeMoneyToRemove = (Decimal(remainingToRemove) / 3600) * Decimal(session.drivingWage)
                session.drivingPay -= activeMoneyToRemove
            }
        }
        
        // Safety clamps
        if session.timeAtHome < 0 { session.timeAtHome = 0 }
        if session.timeAway < 0 { session.timeAway = 0 }
        if session.homePay < 0 { session.homePay = 0 }
        if session.drivingPay < 0 { session.drivingPay = 0 }
    }

    private var perDeliveryBinding: Binding<Double> {
        Binding(
            get: { session.perDeliveryRate ?? 0 },
            set: { session.perDeliveryRate = $0 }
        )
    }
}

// MARK: - Subviews

struct QuickStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 16) {
                content
            }
            .padding()
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal)
    }
}

struct EditableRateRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(
                "Rate",
                value: $value,
                format: .currency(code: "USD")
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .font(.body.bold())
            .foregroundStyle(.primary)
        }
    }
}

#Preview {
    @Previewable @State var showSheet = true
    let mockSession = Session(userSettings: UserSettings())
    mockSession.deliveriesCount = 12
    mockSession.gpsDistanceMeters = 32186  // ~20 miles 
    return Color.clear
        .sheet(isPresented: $showSheet) {
            SessionSummarySheet(session: mockSession)
        }
}

