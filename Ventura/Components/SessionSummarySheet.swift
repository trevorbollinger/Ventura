//
//  .swift
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
    @State private var saveTrigger = false
    var isPresentedAsSheet: Bool = false
    
    @Query private var allSettings: [UserSettings]
    private var settings: UserSettings { allSettings.first ?? UserSettings() }

    @ScaledMetric(relativeTo: .caption) private var arrowSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var mapIconSize: CGFloat = 14

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Premium Header Card
                    SessionStatsCard(session: session, settings: settings, editable: true) {
                        // Time Range Capsule
                        HStack(spacing: 12) {
                            DateStat(title: "Start", date: startBinding)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: arrowSize, weight: .bold))
                                .foregroundStyle(.tertiary)
                            
                            DateStat(title: "End", date: endBinding)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal)




                    // Earnings Section
                    SummarySection(title: "Earnings", icon: "dollarsign.circle.fill") {
                        VStack(spacing: 20) {
                            if session.grossEarnings > 0 {
                                EarningsBreakdownBar(session: session)
                                    .padding(.bottom, 8)
                            }

                            // Income Breakdown
                            if session.wageTypeRaw == "Split" {
                                if session.drivingPay > 0 {
                                    EarningsRow(label: "Driving Pay", value: session.drivingPay, isExpense: false, icon: "steeringwheel", iconColor: Color("WageColor"))
                                }
                                if session.homePay > 0 {
                                    EarningsRow(label: "In-Store Pay", value: session.homePay, isExpense: false, icon: "house.fill", iconColor: Color("PassiveColor"))
                                }
                            } else if session.totalHourlyPay > 0 {
                                EarningsRow(label: "Hourly Pay", value: session.totalHourlyPay, isExpense: false, icon: "clock.fill", iconColor: Color("WageColor"))
                            }
                            
                            if session.totalTips > 0 {
                                EarningsRow(label: "Tips", value: session.totalTips, isExpense: false, icon: "heart.fill", iconColor: Color("TipsColor"))
                            }
                            
                            if session.totalMileageReimbursement > 0 {
                                EarningsRow(label: "Mileage Pay", value: session.totalMileageReimbursement, isExpense: false, icon: "car.fill", iconColor: Color("MileageColor"))
                            }
                            
                            if session.totalDeliveryRates > 0 {
                                EarningsRow(label: "Delivery Fees", value: session.totalDeliveryRates, isExpense: false, icon: "bag.fill", iconColor: Color("MileageColor"))
                            }
                            
                            // Expenses Breakdown
                            if session.fuelExpense > 0 {
                                EarningsRow(label: "Fuel Cost", value: session.fuelExpense, isExpense: true, icon: "fuelpump.fill", iconColor: Color("FuelColor"))
                            }
                            
                            if session.maintenanceExpense > 0 {
                                EarningsRow(label: "Maintenance", value: session.maintenanceExpense, isExpense: true, icon: "wrench.and.screwdriver.fill", iconColor: Color("MaintenanceColor"))
                            }
                            
                            Divider()
//                                .padding(.vertical, 4)

                            HStack {
                                Text("Net Profit")
                                    .font(.headline)
                                    .fontWeight(.bold)

                                Spacer()
                                Text(session.netProfit.formatted(.currency(code: "USD")))
                                    .font(.headline.bold())
                                    .foregroundStyle(.primary)
                            }
                            .padding(.bottom, 4)

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
                            
                            DisclosureGroup {
                                VStack(spacing: 16) {
                                    Divider()
                                    
                                    // Tips List
                                    if !session.tips.isEmpty {
                                        VStack(spacing: 12) {
                                            HStack {
                                                Text("Tips")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                            }
                                            
                                            ForEach(session.tips.indices, id: \.self) { index in
                                                HStack {
                                                    Text("Tip #\(index + 1)")
                                                        .font(.callout)
                                                        .foregroundStyle(.secondary)
                                                    
                                                    Spacer()
                                                    
                                                    Button {
                                                        editingTipIndex = index
                                                    } label: {
                                                        Text(session.tips[index].formatted(.currency(code: "USD")))
                                                            .font(.body.monospacedDigit())
                                                            .foregroundStyle(.primary)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(Color.secondary.opacity(0.1))
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                    
                                                    Button(role: .destructive) {
                                                        session.tips.remove(at: index)
                                                        session.invalidateCache()
                                                    } label: {
                                                        Image(systemName: "trash.fill")
                                                            .foregroundStyle(.red)
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Delivery Counter
                                    HStack {
                                        Text("Deliveries")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("\(session.deliveriesCount)")
                                            .font(.headline)
                                            .monospacedDigit()
                                        
                                        Stepper("Deliveries", value: $session.deliveriesCount, in: 0...999)
                                            .labelsHidden()
                                    }
                                }
                                .padding(.top, 8)
                            } label: {
                                Text("Session Details")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .tint(.primary)
                        }
                        .padding()
                    }


                    // Map Section
                    SummarySection(title: "Route Map", icon: "map.fill") {
                        if session.route.isEmpty {
                            Text("No location data available")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .padding()
                        } else {
                            NavigationLink(destination: RouteMapView(session: session)) {
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
                                        .font(.system(size: mapIconSize, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
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
                                    EditableRateRow(label: "Vehicle MPG", value: $session.vehicleMPG, isCurrency: false)
                                }
                                
                                Toggle("Include Maintenance", isOn: $session.includeMaintenance)
                                if session.includeMaintenance {
                                    EditableRateRow(label: "Maint. Rate / mi", value: $session.maintenanceCostPerMile)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.bottom, 30)

                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isPresentedAsSheet {
                        Button("Done") {
                            saveTrigger.toggle()
                            dismiss()
                        }
                        .bold()
                    }
                }
            }
        .sheet(isPresented: $showAddTipSheet) {
            LogDeliverySheet { amount, countAsDelivery in
                session.tips.append(amount)
                if countAsDelivery {
                    session.deliveriesCount += 1
                }
                session.invalidateCache()
            }
        }
        .sheet(item: Binding(
            get: { editingTipIndex.map { IdentifiableInt(id: $0) } },
            set: { editingTipIndex = $0?.id }
        )) { item in
            LogDeliverySheet(initialValue: session.tips[item.id], isEditing: true) { amount, _ in
                if session.tips.indices.contains(item.id) {
                    session.tips[item.id] = amount
                    session.invalidateCache()
                }
            }
        }
    }

    struct IdentifiableInt: Identifiable {
        let id: Int
    }
    
    // Global helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let doubleHours = NSDecimalNumber(decimal: session.durationInHours)
            .doubleValue
        return TimeFormatter.formatDuration(doubleHours * 3600)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        return TimeFormatter.formatDuration(seconds)
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
        
        // If adding time, attribute to Passive (Home)
        if seconds > 0 {
            session.timeAtHome += seconds
        } else {
            // If removing time, remove from Passive first, then Active
            let removeSeconds = abs(seconds)
            
            if session.timeAtHome >= removeSeconds {
                session.timeAtHome -= removeSeconds
            } else {
                // Remove all remaining passive
                let remainingToRemove = removeSeconds - session.timeAtHome
                session.timeAtHome = 0
                
                // Remove remaining from Active
                session.timeAway -= remainingToRemove
            }
        }
        
        // Safety clamps
        if session.timeAtHome < 0 { session.timeAtHome = 0 }
        if session.timeAway < 0 { session.timeAway = 0 }
    }

    private var perDeliveryBinding: Binding<Double> {
        Binding(
            get: { session.perDeliveryRate ?? 0 },
            set: { session.perDeliveryRate = $0 }
        )
    }
}

// MARK: - Subviews



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
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal)
    }
}

struct DateStat: View {
    let title: String
    @Binding var date: Date
    @State private var showPicker = false
    @ScaledMetric(relativeTo: .caption2) private var headerSize: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var textSize: CGFloat = 15
    
    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: headerSize, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
                .textCase(.uppercase)
            
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: textSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showPicker = true
        }
        .popover(isPresented: $showPicker) {
            VStack(spacing: 16) {
                Text("Select \(title) Time")
                    .font(.headline)
                
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}

struct EditableRateRow: View {
    let label: String
    @Binding var value: Double
    var isCurrency: Bool = true

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            
            Group {
                if isCurrency {
                    TextField(
                        "Rate",
                        value: $value,
                        format: .currency(code: "USD")
                    )
                } else {
                    TextField(
                        "Value",
                        value: $value,
                        format: .number
                    )
                }
            }
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .font(.body.bold())
            .foregroundStyle(.primary)
        }
    }
}

struct EarningsRow: View {
    let label: String
    let value: Decimal
    let isExpense: Bool
    var icon: String? = nil
    var iconColor: Color? = nil
    @ScaledMetric(relativeTo: .caption) private var rowIconSize: CGFloat = 14
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: rowIconSize, weight: .bold))
                    .foregroundStyle(iconColor ?? .secondary)
                    .frame(width: 20)
            }
            
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(isExpense ? "-" : "+")
                .font(.caption.bold())
                .foregroundStyle(isExpense ? Color("MaintenanceColor") : Color("TipsColor"))
            Text(value.formatted(.currency(code: "USD")))
                .fontWeight(.semibold)
                .foregroundStyle(isExpense ? Color("MaintenanceColor") : Color("TipsColor"))
        }
    }
}

struct EarningsBreakdownBar: View {
    @Bindable var session: Session
    
    // Decomposed wage buckets for graph
    private var drivingPay: Double {
        session.wageTypeRaw == "Split" ? NSDecimalNumber(decimal: session.drivingPay).doubleValue : 0
    }
    private var homePay: Double {
        session.wageTypeRaw == "Split" ? NSDecimalNumber(decimal: session.homePay).doubleValue : 0
    }
    private var hourlyTotal: Double {
        session.wageTypeRaw == "Hourly" ? NSDecimalNumber(decimal: session.totalHourlyPay).doubleValue : 0
    }
    
    private var tips: Double { NSDecimalNumber(decimal: session.totalTips).doubleValue }
    private var mileage: Double { NSDecimalNumber(decimal: session.totalMileageReimbursement).doubleValue }
    private var fees: Double { NSDecimalNumber(decimal: session.totalDeliveryRates).doubleValue }
    
    private var fuel: Double { NSDecimalNumber(decimal: session.fuelExpense).doubleValue }
    private var maintenance: Double { NSDecimalNumber(decimal: session.maintenanceExpense).doubleValue }
    
    // Total Gross Earnings (Width reference)
    private var totalGross: Double { drivingPay + homePay + hourlyTotal + tips + mileage + fees }

    // Logic to distribute expenses
    private struct ReducedSegment {
        let original: Double
        let display: Double
    }
    
    private var expenseAdjustedSegments: (driving: Double, home: Double, hourly: Double, tips: Double, mileage: Double, fees: Double) {
        let sources = [drivingPay, homePay, hourlyTotal, tips, mileage, fees]
        let activeCount = Double(sources.filter { $0 > 0 }.count)
        
        guard activeCount > 0 else { return (0, 0, 0, 0, 0, 0) }
        
        let totalExpenses = fuel + maintenance
        let deductionPerSource = totalExpenses / activeCount
        
        func reduce(_ value: Double) -> Double {
            return value > 0 ? max(0, value - deductionPerSource) : 0
        }
        
        return (
            reduce(drivingPay),
            reduce(homePay),
            reduce(hourlyTotal),
            reduce(tips),
            reduce(mileage),
            reduce(fees)
        )
    }

    var body: some View {
        GeometryReader { geo in
            if totalGross > 0 {
                let segs = expenseAdjustedSegments
                
                HStack(spacing: 2) {
                    if segs.driving > 0 {
                        segment(width: geo.size.width * (segs.driving / totalGross), color: Color("WageColor"))
                    }
                    if segs.home > 0 {
                        segment(width: geo.size.width * (segs.home / totalGross), color: Color("PassiveColor"))
                    }
                    if segs.hourly > 0 {
                        segment(width: geo.size.width * (segs.hourly / totalGross), color: Color("WageColor"))
                    }
                    if segs.tips > 0 {
                        segment(width: geo.size.width * (segs.tips / totalGross), color: Color("TipsColor"))
                    }
                    if segs.mileage > 0 {
                        segment(width: geo.size.width * (segs.mileage / totalGross), color: Color("MileageColor"))
                    }
                    if segs.fees > 0 {
                        segment(width: geo.size.width * (segs.fees / totalGross), color: Color("MileageColor"))
                    }
                    
                    // Expense Segments
                    if fuel > 0 {
                        segment(width: geo.size.width * (fuel / totalGross), color: Color("FuelColor"))
                    }
                    if maintenance > 0 {
                        segment(width: geo.size.width * (maintenance / totalGross), color: Color("MaintenanceColor"))
                    }
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }
    
    private func segment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.gradient)
            .frame(width: max(0, width - 2))
    }
}

#Preview {
    @Previewable @State var showSheet = true
    let mockSession = PreviewHelper.generateMockSessions().first!
    
    Color.clear
        .sheet(isPresented: $showSheet) {
            SessionSummarySheet(session: mockSession)
        }
}

