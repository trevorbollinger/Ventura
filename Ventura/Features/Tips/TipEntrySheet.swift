//
//  RateConflictSheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI

struct TipEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Decimal) -> Void

    @State private var amount: Decimal?
    @State private var sliderValue: Double = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Display Value
                    TextField(
                        "$0.00",
                        value: $amount,
                        format: .currency(code: "USD")
                    )
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.clear)

                    // Quick Entry Slider
                    VStack(spacing: 12) {
                        HStack {
                            Text("Quick Add")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(
                                sliderValue == 0
                                    ? "Slide to select" : "$\(Int(sliderValue))"
                            )
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        }

                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Slider(value: $sliderValue, in: 0...10, step: 1)
                                .tint(.green)

                            Text("10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Add Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount = amount, amount > 0 {
                            onSave(amount)
                            dismiss()
                        }
                    }
                    .font(.headline)
                    .disabled(amount == nil || amount == 0)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.fraction(0.45), .fraction(0.95)])
            .presentationDragIndicator(.hidden)
        #endif
//        .presentationDragIndicator(.visible)

        // Update text field when slider moves
        .onChange(of: sliderValue) { _, newValue in
            // Only update if it's a deliberate user action loop break
            let decimalVal = Decimal(newValue)
            if amount != decimalVal {
                amount = decimalVal
            }
        }
        // Update slider if user types an integer
        .onChange(of: amount) { _, newValue in
            if let val = newValue {
                let doubleVal = NSDecimalNumber(decimal: val).doubleValue
                // Check if integer and within slider range
                // Use a small epsilon for float comparison safety
                let isInteger = abs(doubleVal - round(doubleVal)) < 0.001

                if isInteger && doubleVal >= 0 && doubleVal <= 10 {
                    if abs(sliderValue - doubleVal) > 0.001 {
                        sliderValue = doubleVal
                    }
                }
            }
        }
    }
}

#Preview {
    TipEntrySheet { _ in }
}
