import SwiftUI

struct DriveSessionHeader: View {
    let tickerState: SessionManager.ActiveSessionState
    let settings: UserSettings
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Profit Label
            Text(tickerState.netProfit.formatted(.currency(code: settings.currencyCode)))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())
                .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Row 1 Stats: Duration, Distance, Deliveries, Primary Metric
            HStack(spacing: 15) {
                StatItem(
                    icon: "clock.fill",
                    color: Color("WageColor"),
                    label: "Time",
                    value: TimeFormatter.formatDuration(tickerState.totalDuration)
                )
                
                StatItem(
                    icon: "car.fill",
                    color: Color("MileageColor"),
                    label: settings.distanceUnit == .kilometers ? "Km" : "Miles",
                    value: String(format: "%.1f", tickerState.distanceMeters / 1609.34)
                )
                
                StatItem(
                    icon: "briefcase.fill",
                    color: .blue,
                    label: "Deliveries",
                    value: "\(tickerState.deliveriesCount)"
                )
                
                if settings.primaryMetric == .hourly {
                    StatItem(
                        icon: "hourglass",
                        color: Color("TipsColor"),
                        label: "Per Hour",
                        value: tickerState.netHourly.formatted(.currency(code: settings.currencyCode))
                    )
                } else {
                    StatItem(
                        icon: "road.lanes",
                        color: Color("FuelColor"),
                        label: settings.distanceUnit == .kilometers ? "Per Km" : "Per Mile",
                        value: tickerState.netPerDistance.formatted(.currency(code: settings.currencyCode))
                    )
                }
            }
            
            let primaryIsHourly = settings.primaryMetric == .hourly
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, 40)
                    .transition(.opacity)
                
                // Row 2 (Expandable): Secondary Metric, Avg Tip, Home, Driving
                HStack(spacing: 15) {
                    if primaryIsHourly {
                        StatItem(
                            icon: "road.lanes",
                            color: Color("FuelColor"),
                            label: settings.distanceUnit == .kilometers ? "Per Km" : "Per Mile",
                            value: tickerState.netPerDistance.formatted(.currency(code: settings.currencyCode))
                        )
                    } else {
                        StatItem(
                            icon: "hourglass",
                            color: Color("TipsColor"),
                            label: "Per Hour",
                            value: tickerState.netHourly.formatted(.currency(code: settings.currencyCode))
                        )
                    }
                    
                    StatItem(
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        label: "Avg Tip",
                        value: tickerState.averageTip.formatted(.currency(code: settings.currencyCode))
                    )
                    
                    // Conditionally show Home/Driving if home is set, else omit or show empty placeholders
                    if settings.homeLatitude != nil {
                        StatItem(
                            icon: "house.fill",
                            color: Color("PassiveColor"),
                            label: "Home",
                            value: TimeFormatter.formatDuration(tickerState.timeAtHome)
                        )
                        
                        StatItem(
                            icon: "steeringwheel",
                            color: Color("WageColor"),
                            label: "Driving",
                            value: TimeFormatter.formatDuration(tickerState.timeAway)
                        )
                    } else {
                       Spacer()
                       Spacer()
                    }
                }
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
            }
            
            // Expand/collapse indicator
            Image(systemName: "chevron.compact.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .contentShape(Rectangle()) // makes the whole area tappable if needed, though we apply the gesture to the parent
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 32))
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Previews

#Preview("Session Header") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        DriveSessionHeader(
            tickerState: PreviewHelper.mockActiveSessionState,
            settings: PreviewHelper.mockSettings()
        )
        .padding()
    }
}

#Preview("Session Header – No Home") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        DriveSessionHeader(
            tickerState: PreviewHelper.mockActiveSessionState,
            settings: PreviewHelper.mockSettingsNoHome()
        )
        .padding()
    }
}
