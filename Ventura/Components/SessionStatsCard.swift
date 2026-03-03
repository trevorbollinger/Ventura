import SwiftData
import SwiftUI

struct SessionStatsCard<Footer: View>: View {
    let session: Session?
    let settings: UserSettings
    let isLive: Bool
    let timelineDate: Date
    let editable: Bool
    let showHomeStats: Bool
    let sessionState: SessionManager.ActiveSessionState? // Changed from LiveMetrics
    
    @ScaledMetric(relativeTo: .largeTitle) private var profitSize: CGFloat = 52
    @State private var showDeliveriesPicker = false
    @ViewBuilder let footer: Footer
    
    init(
        session: Session?,
        settings: UserSettings,
        isLive: Bool = false,
        timelineDate: Date = Date(),
        editable: Bool = false,
        showHomeStats: Bool = true,
        sessionState: SessionManager.ActiveSessionState? = nil,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.session = session
        self.settings = settings
        self.isLive = isLive
        self.timelineDate = timelineDate
        self.editable = editable
        self.showHomeStats = showHomeStats
        self.sessionState = sessionState
        self.footer = footer()
    }

    var body: some View {
        content(date: timelineDate)
    }

    private func content(date: Date) -> some View {
        let metrics = calculateMetrics()
        
        return VStack(spacing: 14) {
            // Determine what to show: Active Session -> Last Session -> Empty State
            // (Passed in session should already be the correct one)

            // 0. Header
            if session != nil {
                HStack {
                    // Add small pulsing circle indicaotr thing here.

                    Text(
                        isLive
                            ? "Tracking Session"
                            : (session != nil
                                ? "Previous Session" : "Welcome to Ventura")
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                    Spacer()

                    Text(
                        isLive
                            ? "" : (session?.startTimestamp.formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day().year()) ?? "")
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                }
                Divider()
            }

            // 1. Profit Hero
            VStack(spacing: 4) {
                Text(
                    (metrics.netProfit).formatted(.currency(code: session?.currencyCode ?? "USD"))
                )
                .font(.system(size: profitSize, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())
                .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
            }

            if showHomeStats {
                // ROW 1: Time, Miles, Home, Driving
                HStack(alignment: .top) {
                    Spacer()

                    StatItem(
                        icon: "clock.fill",
                        color: Color("WageColor"),
                        label: "Time",
                        value: sessionState != nil ? TimeFormatter.formatDuration(sessionState!.totalDuration) : durationString(at: date)
                    )
                    Spacer()
                    
                    StatItem(
                        icon: "house.fill",
                        color: Color("PassiveColor"),
                        label: "HOME",
                        value: formatSeconds(sessionState?.timeAtHome ?? session?.timeAtHome ?? 0)
                    )
                    Spacer()
                    StatItem(
                        icon: "steeringwheel",
                        color: Color("WageColor"),
                        label: "DRIVING",
                        value: formatSeconds(sessionState?.timeAway ?? session?.timeAway ?? 0)
                    )
                    Spacer()
                    StatItem(
                        icon: "car.fill",
                        color: Color("MileageColor"),
                        label: settings.distanceUnit == .kilometers ? "Km" : "Miles",
                        value: String(format: "%.1f", settings.displayDistance(miles: (sessionState?.distanceMeters ?? session?.gpsDistanceMeters ?? 0) / 1609.34))
                    )
                    Spacer()
                }

                // ROW 2: Deliveries, Per Hour, Per Mile
                HStack(alignment: .top) {
                    Spacer()

                    
                    //deliveries
                    deliveriesItem
                    Spacer()

                    //perhour
                    StatItem(
                        icon: "hourglass",
                        color: Color("TipsColor"),
                        label: "PER HOUR",
                        value: (metrics.hourly).formatted(
                            .currency(code: session?.currencyCode ?? "USD")
                        )
                    )
                    Spacer()
                    
                    //permile
                    StatItem(
                        icon: "road.lanes",
                        color: Color("FuelColor"),
                        label: settings.distanceUnit == .kilometers ? "PER KM" : "PER MILE",
                        value: formattedNetPerDistance(metrics: metrics)
                    )
                    Spacer()

                }

            } else {
                // ROW 1: Time, Miles, Deliveries
                HStack(alignment: .top) {
                    Spacer()
                    //time
                    StatItem(
                        icon: "clock.fill",
                        color: Color("WageColor"),
                        label: "Time",
                        value: sessionState != nil ? TimeFormatter.formatDuration(sessionState!.totalDuration) : durationString(at: date)
                    )
                    Spacer()
                    //miles
                    StatItem(
                        icon: "car.fill",
                        color: Color("MileageColor"),
                        label: settings.distanceUnit == .kilometers ? "Km" : "Miles",
                        value: String(format: "%.1f", settings.displayDistance(miles: (sessionState?.distanceMeters ?? session?.gpsDistanceMeters ?? 0) / 1609.34))
                    )
                    Spacer()

                    //deliveries
                    deliveriesItem
                    Spacer()

                }

                // ROW 2: Per Hour, Per Mile
                HStack(alignment: .top) {
                    Spacer()

                    //perhour
                    StatItem(
                        icon: "hourglass",
                        color: Color("TipsColor"),
                        label: "PER HOUR",
                        value: (metrics.hourly).formatted(
                            .currency(code: session?.currencyCode ?? "USD")
                        )
                    )
                    Spacer()
                    //permile
                    StatItem(
                        icon: "road.lanes",
                        color: Color("FuelColor"),
                        label: settings.distanceUnit == .kilometers ? "PER KM" : "PER MILE",
                        value: formattedNetPerDistance(metrics: metrics)
                    )
                    Spacer()

                }
            }

            // 4. Footer (if any)
            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassModifier(in: RoundedRectangle(cornerRadius: 32))
        .shadow(
            color: isLive ? .green.opacity(0.1) : .clear,
            radius: 20,
            x: 0,
            y: 10
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private var deliveriesItem: some View {
        StatItem(
            icon: "briefcase.fill",
            color: .blue,
            label: "DELIVERIES",
            value: "\(sessionState?.deliveriesCount ?? session?.deliveriesCount ?? 0)"
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if editable {
                showDeliveriesPicker = true
            }
        }
        .popover(isPresented: $showDeliveriesPicker) {
            VStack {
                Text("Deliveries")
                .font(.headline)
                Picker(
                    "Deliveries",
                    selection: Binding(
                        get: { session?.deliveriesCount ?? 0 },
                        set: { session?.deliveriesCount = $0 }
                    )
                ) {
                    ForEach(0...100, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    private func formattedNetPerDistance(metrics: (netProfit: Double, hourly: Double, perDist: Double)) -> String {
        let converted = settings.displayPerDistance(perMile: metrics.perDist)
        return converted.formatted(.currency(code: session?.currencyCode ?? "USD"))
    }

    private func durationString(at date: Date) -> String {
        guard let session = session else { return "0m 0s" }
        return session.durationString(
            at: isLive ? date : (session.endTimestamp ?? date)
        )
    }

    private func formatSeconds(_ seconds: Double) -> String {
        return TimeFormatter.formatDuration(seconds)
    }

    // On-the-fly calc
    private func calculateMetrics() -> (netProfit: Double, hourly: Double, perDist: Double) {
        if let sState = sessionState {
            return (sState.netProfit, sState.netHourly, sState.netPerDistance)
        }
        
        guard let session = session else { return (0,0,0) }
        
        // Use live state if available, else session totals
        let timeAway = session.timeAway
        let timeAtHome = session.timeAtHome
        let distMeters = session.gpsDistanceMeters
        let totalTime = timeAway + timeAtHome
        let miles = distMeters / 1609.34
        
        // 1. Wage
        var wage: Double = 0
        if session.wageTypeRaw == "Hourly" {
             wage = (totalTime / 3600.0) * session.hourlyWage
        } else if session.wageTypeRaw == "Split" {
             wage = ((timeAway / 3600.0) * session.drivingWage) + 
                    ((timeAtHome / 3600.0) * session.passiveWage)
        }
        
        // 2. Reimbursements
        var reimbursement: Double = 0
        if session.reimbursementTypeRaw == "Per Mile" {
            reimbursement = miles * session.mileageReimbursementRate
        } else if session.reimbursementTypeRaw == "Per Delivery" {
            reimbursement = Double(session.deliveriesCount) * (session.perDeliveryRate ?? 0)
        }
        
        // 3. Tips
        let tips = session.tips.reduce(0) { $0 + NSDecimalNumber(decimal: $1).doubleValue }
        
        let gross = wage + reimbursement + tips
        
        // 4. Expenses
        var expenses: Double = 0
        if session.includeGas && session.vehicleMPG > 0 {
            expenses += (miles / session.vehicleMPG) * session.fuelPrice
        }
        if session.includeMaintenance {
            expenses += miles * session.maintenanceCostPerMile
        }
        
        let net = gross - expenses
        
        let hours = totalTime / 3600.0
        let hourly = hours > 0 ? net / hours : 0
        let perDist = miles > 0 ? net / miles : 0
        
        return (net, hourly, perDist)
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    let descriptor = FetchDescriptor<Session>()
    let sessions = try? container.mainContext.fetch(descriptor)
    let session = sessions?.first

    return ScrollView {
        VStack(spacing: 30) {
            Group {
                Text("Live State (Home Set)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    settings: UserSettings(),
                    isLive: true,
                    showHomeStats: true
                )

                Text("Live State (No Home)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    settings: UserSettings(),
                    isLive: true,
                    showHomeStats: false
                )
            }

            Divider()

            Group {
                Text("Completed (Home Set)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    settings: UserSettings(),
                    isLive: false,
                    showHomeStats: true
                )

                Text("Completed (No Home)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    settings: UserSettings(),
                    isLive: false,
                    showHomeStats: false
                )
            }

            Divider()

            Group {
                Text("Empty State")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(session: nil, settings: UserSettings())
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
