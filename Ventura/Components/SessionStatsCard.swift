import SwiftUI
import SwiftData

struct SessionStatsCard<Footer: View>: View {
    let session: Session?
    let isLive: Bool
    let timelineDate: Date
    let editable: Bool
    @State private var showDeliveriesPicker = false
    @ViewBuilder let footer: Footer
    
    init(
        session: Session?,
        isLive: Bool = false,
        timelineDate: Date = Date(),
        editable: Bool = false,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.session = session
        self.isLive = isLive
        self.timelineDate = timelineDate
        self.editable = editable
        self.footer = footer()
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Determine what to show: Active Session -> Last Session -> Empty State
            // (Passed in session should already be the correct one)
            
            // 0. Header
            if session != nil {
                HStack {
                    // Add small pulsing circle indicaotr thing here.
                    
                    Text(isLive ? "Tracking Session" : (session != nil ? "Previous Session" : "Welcome to Ventura"))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text(isLive ? "" : (session != nil ? "Sunday, Feb 1, 2026" : ""))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Divider()
            }
           
            
            // 1. Profit Hero
            VStack(spacing: 4) {
                
                
                Text(session?.netProfit.formatted(.currency(code: "USD")) ?? "$0.00")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
                    .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
            }

            // 2. Stats Row
            HStack(alignment: .top) {
                
                StatItem(
                    icon: "clock.fill",
                    color: Color("WageColor"),
                    label: "Time",
                    value: durationString
                )
                Spacer()
                StatItem(
                    icon: "car.fill",
                    color: Color("MileageColor"),
                    label: "Miles",
                    value: session != nil ? String(format: "%.1f", session!.totalMiles) : "0.0"
                )
                Spacer()
                StatItem(
                    icon: "road.lanes",
                    color: Color("FuelColor"),
                    label: "PER MILE",
                    value: formattedNetPerMile
                )
                Spacer()
                StatItem(
                    icon: "hourglass",
                    color: Color("TipsColor"),
                    label: "PER HOUR",
                    value: session?.earningsPerHour.formatted(.currency(code: "USD")) ?? "$0.00"
                )
            }
            .padding(.horizontal, 8)
            
            // 3. Movement Split
            // 3. Movement & Deliveries (Row 2)
            HStack(alignment: .top) {
                 StatItem(
                   icon: "house.fill",
                   color: Color("PassiveColor"),
                   label: "HOME",
                   value: formatSeconds(session?.timeAtHome ?? 0)
               )
               Spacer()
                StatItem(
                    icon: "steeringwheel",
                    color: Color("WageColor"),
                    label: "DRIVING",
                    value: formatSeconds(session?.timeAway ?? 0)
                )
                Spacer()
               
                StatItem(
                    icon: "briefcase.fill",
                    color: .blue,
                    label: "DELIVERIES",
                    value: "\(session?.deliveriesCount ?? 0)"
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
                        Picker("Deliveries", selection: Binding(
                            get: { session?.deliveriesCount ?? 0 },
                            set: { session?.deliveriesCount = $0 }
                        )) {
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
            .padding(.horizontal, 8)
            
            // 4. Footer (if any)
            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassModifier(in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: isLive ? .green.opacity(0.1) : .clear, radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Helpers
    
    private var formattedNetPerMile: String {
        guard let session = session, session.totalMiles > 0 else { return "$0.00" }
        let profit = session.netProfit
        let miles = Decimal(session.totalMiles)
        return (profit / miles).formatted(.currency(code: "USD"))
    }

    private var durationString: String {
        guard let session = session else { return "0m 0s" }
        return session.durationString(at: isLive ? timelineDate : (session.endTimestamp ?? timelineDate))
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        
        if h > 0 {
            return String(format: "%dh %dm", h, m)
        } else {
            return String(format: "%dm %ds", m, s)
        }
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    let descriptor = FetchDescriptor<Session>()
    let sessions = try? container.mainContext.fetch(descriptor)
    let session = sessions?.first

    return ScrollView {
        VStack(spacing: 20) {
            Text("Live State")
                .font(.caption)
                .foregroundStyle(.secondary)
            SessionStatsCard(session: session, isLive: true)
            
            Text("Completed Session")
                .font(.caption)
                .foregroundStyle(.secondary)
            SessionStatsCard(session: session, isLive: false)
            
            Text("Empty State")
                .font(.caption)
                .foregroundStyle(.secondary)
            SessionStatsCard(session: nil)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}


