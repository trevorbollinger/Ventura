//
//  SessionInfoLiveActivityShared.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

// MARK: - Attributes Extensions

extension SessionActivityAttributes {
    static var preview: SessionActivityAttributes {
        SessionActivityAttributes(
            startTime: Date()
        )
    }

    static var previewOverOneHour: SessionActivityAttributes {
        SessionActivityAttributes(
            startTime: Date().addingTimeInterval(-3900)
        )
    }
}

extension SessionActivityAttributes.ContentState {
    static var active: SessionActivityAttributes.ContentState {
        SessionActivityAttributes.ContentState(
            totalEarnings: 32.50,
            netProfit: 28.50,
            netHourlyProfit: 18.00,
            netPerDistance: 2.30,
            deliveryCount: 3,
            totalDistance: 12.4,
            lastUpdated: Date(),
            currencyCode: "USD",
            distanceUnitRaw: "mi"
        )
    }
}

// MARK: - Shared Components

struct LiveActivityHeader: View {
    let title: String
    let startTime: Date
    @ScaledMetric(relativeTo: .caption) private var headerSize: CGFloat = 13

    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            Text(
                timerInterval: startTime...Date.distantFuture,
                countsDown: false
            )
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 2)
        .font(.system(size: headerSize, weight: .bold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
    }
}

struct LiveActivityProfitHero: View {
    let profit: Double
    var currencyCode: String = "USD"
    @ScaledMetric(relativeTo: .largeTitle) private var profitSize: CGFloat = 36

    var body: some View {
        Text(profit, format: .currency(code: currencyCode))
            .font(.system(size: profitSize, weight: .black, design: .rounded))
            .foregroundStyle(.green)
            .contentTransition(.numericText())
            .padding(4)
    }
}

struct LiveActivityStatsRow: View {
    let state: SessionActivityAttributes.ContentState
    let attributes: SessionActivityAttributes

    var body: some View {
        HStack(alignment: .top) {
            Spacer()
            LiveActivityStatItem(
                icon: "car.fill",
                color: Color("MileageColor"),
                label: state.distanceUnitRaw == "km" ? "KM" : "MILES",
                value: String(format: "%.1f", state.totalDistance)
            )
            Spacer()
            LiveActivityStatItem(
                icon: "briefcase.fill",
                color: .blue,
                label: "DELIV.",
                value: "\(state.deliveryCount)"
            )
            Spacer()
            LiveActivityStatItem(
                icon: "hourglass",
                color: Color("TipsColor"),
                label: "/ HOUR",
                value: state.netHourlyProfit.formatted(
                    .currency(code: state.currencyCode)
                )
            )
            Spacer()
            LiveActivityStatItem(
                icon: "road.lanes",
                color: Color("FuelColor"),
                label: state.distanceUnitRaw == "km" ? "/ KM" : "/ MILE",
                value: state.netPerDistance.formatted(
                    .currency(code: state.currencyCode)
                )
            )
            Spacer()
        }
    }
}

struct LiveActivityStatItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .subheadline) private var statValueSize: CGFloat =
        15
    @ScaledMetric(relativeTo: .caption2) private var statLabelSize: CGFloat = 9

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(
                    .system(
                        size: statValueSize,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: statLabelSize, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

struct CompactTimer: View {
    let startTime: Date
    
    private let fontSize: CGFloat = 13
    private var font: UIFont {
        UIFont.systemFont(ofSize: fontSize, weight: .bold).rounded
    }
    
    var body: some View {
        Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: calculatedWidth, alignment: .leading)
            .lineLimit(1)
    }
    
    private var calculatedWidth: CGFloat {
        let duration = max(0, Date().timeIntervalSince(startTime))
        let sampleString: String
        
        // Match the user's expected max width patterns
        if duration < 3600 {
            sampleString = "00:00"
        } else if duration < 36000 {
            sampleString = "0:00:00"
        } else {
            sampleString = "00:00:00"
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        
        return (sampleString as NSString).size(withAttributes: attributes).width + 2
    }
}

extension UIFont {
    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
