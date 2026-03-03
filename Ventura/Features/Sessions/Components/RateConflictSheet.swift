//
//  RateConflictSheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI

struct RateConflictSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [Session]
    let conflictingFields: [String]
    let onNormalize: (Session) -> Void
    
    @State private var selectedReferenceSession: Session?
    
    private var rateGroups: [(rateInfo: Session.RateInfo, sessions: [Session])] {
        let groups = SessionCombiner.groupByRates(sessions)
        return groups.map { (rateInfo: $0.key, sessions: $0.value) }
            .sorted { 
                if $0.sessions.count != $1.sessions.count {
                    return $0.sessions.count > $1.sessions.count
                }
                if $0.rateInfo.hourlyWage != $1.rateInfo.hourlyWage {
                    return $0.rateInfo.hourlyWage > $1.rateInfo.hourlyWage
                }
                return $0.rateInfo.vehicleMPG > $1.rateInfo.vehicleMPG
            }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with error info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Rate Conflict Detected")
                            .font(.headline)
                    }
                    
                    Text("The following fields differ between selected sessions:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(conflictingFields, id: \.self) { field in
                            Text(field)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                
                .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                .background(.orange.opacity(0.3))
                .cornerRadius(20)
               
                // Instructions
                Text("Select which rate set to apply to all sessions:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Rate options
                List {
                    ForEach(rateGroups, id: \.rateInfo) { group in
                        RateGroupRow(
                            rateInfo: group.rateInfo,
                            sessionCount: group.sessions.count,
                            isSelected: selectedReferenceSession?.id == group.sessions.first?.id
                        )
                        
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedReferenceSession = group.sessions.first
                        }
                    }
                }
              
                .listStyle(.plain)
//                .backgroud(.none)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        if let reference = selectedReferenceSession {
                            onNormalize(reference)
                        }
                    } label: {
                        Text("Normalize & Combine")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            
                            .foregroundStyle(.white)
                            .glassModifier(in: RoundedRectangle(cornerRadius: 20))

                    }
                    .disabled(selectedReferenceSession == nil)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
            }
            .navigationBarTitleDisplayMode(.inline)
            .padding(.top, 7)
            .padding()
        }
    }
}

struct RateGroupRow: View {
    let rateInfo: Session.RateInfo
    let sessionCount: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .blue : .gray.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sessionCount) session\(sessionCount > 1 ? "s" : "") with these rates")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 2) {
                    if rateInfo.hourlyWage > 0 {
                        Text("Hourly: \(rateInfo.hourlyWage.formatted(.currency(code: "USD")))/hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if rateInfo.passiveWage > 0 {
                        Text("Passive: \(rateInfo.passiveWage.formatted(.currency(code: "USD")))/hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let perDelivery = rateInfo.perDeliveryRate, perDelivery > 0 {
                        Text("Per Delivery: \(perDelivery.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if rateInfo.mileageReimbursementRate > 0 {
                        Text("Mileage: \(rateInfo.mileageReimbursementRate.formatted(.currency(code: "USD")))/mi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("MPG: \(String(format: "%.1f", rateInfo.vehicleMPG)) • Fuel: \(rateInfo.fuelPrice.formatted(.currency(code: "USD")))/gal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
#Preview("Rate Conflict Sheet") {
    let settings1 = UserSettings(mpg: 24.0, hourlyWage: 15.0)
    let settings2 = UserSettings(mpg: 28.0, hourlyWage: 20.0)
    
    let session1 = Session(startTimestamp: Date().addingTimeInterval(-7200), userSettings: settings1)
    session1.endTimestamp = Date().addingTimeInterval(-3600)
    
    let session2 = Session(startTimestamp: Date().addingTimeInterval(-14400), userSettings: settings1)
    session2.endTimestamp = Date().addingTimeInterval(-10800)
    
    let session3 = Session(startTimestamp: Date().addingTimeInterval(-21600), userSettings: settings2)
    session3.endTimestamp = Date().addingTimeInterval(-18000)
    
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            RateConflictSheet(
                sessions: [session1, session2, session3],
                conflictingFields: ["Hourly Wage", "Vehicle MPG"],
                onNormalize: { _ in }
            )
        }
}
