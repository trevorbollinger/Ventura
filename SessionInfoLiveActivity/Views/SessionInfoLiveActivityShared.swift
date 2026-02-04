//
//  SessionInfoLiveActivityShared.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes Extensions

extension SessionActivityAttributes {
    static var preview: SessionActivityAttributes {
        SessionActivityAttributes(
            startTime: Date()
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
