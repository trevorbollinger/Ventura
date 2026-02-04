//
//  PreviousSessionCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI
import SwiftData

struct PreviousSessionCard: View {
    let session: Session?
    
    @ScaledMetric(relativeTo: .title) private var profitSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var valueSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 9
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Previous Session")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if let session = session {
                    Text(session.startTimestamp.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
            }
            
            if let session = session {
                // Profit Display
                Text(session.netProfit.formatted(.currency(code: "USD")))
                    .font(.system(size: profitSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Stats Row
                HStack(alignment: .top, spacing: 0) {
                    Spacer()
                    
                    // Time
                    CompactStatItem(
                        icon: "clock.fill",
                        color: Color("WageColor"),
                        label: "Time",
                        value: session.durationString(at: session.endTimestamp ?? Date()),
                        iconSize: iconSize,
                        valueSize: valueSize,
                        labelSize: labelSize
                    )
                    
                    Spacer()
                    
                    // Miles
                    CompactStatItem(
                        icon: "car.fill",
                        color: Color("MileageColor"),
                        label: "Miles",
                        value: String(format: "%.1f", session.totalMiles),
                        iconSize: iconSize,
                        valueSize: valueSize,
                        labelSize: labelSize
                    )
                    
                    Spacer()
                    
                    // Deliveries
                    CompactStatItem(
                        icon: "briefcase.fill",
                        color: .blue,
                        label: "Deliveries",
                        value: "\(session.deliveriesCount)",
                        iconSize: iconSize,
                        valueSize: valueSize,
                        labelSize: labelSize
                    )
                    
                    Spacer()
                }
                
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No Previous Session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassModifier(in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Compact Stat Item
struct CompactStatItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let iconSize: CGFloat
    let valueSize: CGFloat
    let labelSize: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.system(size: labelSize, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    let descriptor = FetchDescriptor<Session>(
        predicate: #Predicate<Session> { $0.endTimestamp != nil },
        sortBy: [SortDescriptor(\Session.endTimestamp, order: .reverse)]
    )
    let sessions = try? container.mainContext.fetch(descriptor)
    let lastSession = sessions?.first
    
    return ScrollView {
        VStack(spacing: 20) {
            Text("With Session Data")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            PreviousSessionCard(session: lastSession)
                .onTapGesture {
                    print("Tapped session card")
                }
            
            Divider()
            
            Text("Empty State")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            PreviousSessionCard(session: nil)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
