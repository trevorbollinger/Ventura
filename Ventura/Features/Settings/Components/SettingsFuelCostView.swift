//
//  SettingsFuelCostView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/29/26.
//

import SwiftUI
import SwiftData

struct SettingsFuelCostView: View {
    @Bindable var userSettings: UserSettings
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("Include Fuel Cost", isOn: $userSettings.includeGas)
            } footer: {
               // Text("If enabled, fuel expenses will be deducted from your net profit based on your MPG.")
            }
            
            if userSettings.includeGas {
                Section("Vehicle Efficiency") {
                    HStack {
                        Text("Average MPG")
                        Spacer()
                        Text("\(Int(userSettings.mpg)) mpg")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $userSettings.mpg, in: 5...60, step: 1)
                            .labelsHidden()
                    }
                }
            }
            
            if userSettings.includeGas {
                Section("Fuel Price") {
                    HStack {
                        Text("Price per Gallon")
                        Spacer()
                        TextField("Price", value: $userSettings.fuelPrice, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .focused($isFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Presets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            presetButton(title: "Budget", cost: 2.50, color: .green)
                            presetButton(title: "National Avg", cost: 3.20, color: .blue)
                            presetButton(title: "Premium", cost: 4.00, color: .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fuel Usage")
                        .font(.headline)
                    
                    Text("Fuel Price and MPG is used to automatically deduct the estimated cost of fuel you've used from your net profit for more accurate earning insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
    
                }
                
            }
            
            if userSettings.includeGas {
                 Section("Preset Guide") {
                     VStack(alignment: .leading, spacing: 12) {
                         presetInfo(title: "Budget ($2.50/gal)", desc: "For low-cost regions or discount fuel memberships.")
                         presetInfo(title: "National Avg ($3.20/gal)", desc: "A reasonable baseline if you're unsure of current local prices.")
                         presetInfo(title: "Premium ($4.00/gal)", desc: "For high-cost regions (e.g., California) or premium fuel grades.")
                     }
                 }
            }
        }
        .navigationTitle("Fuel Config")
        .toolbar {
             ToolbarItem(placement: .keyboard) {
                 HStack {
                     Spacer()
                     Button("Done") {
                         isFocused = false
                     }
                     .bold()
                 }
             }
         }
    }
    
    private func presetButton(title: String, cost: Double, color: Color) -> some View {
        Button {
            userSettings.fuelPrice = cost
        } label: {
            VStack {
                Text(title)
                    .font(.caption.bold())
                Text(cost.formatted(.currency(code: "USD")))
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(userSettings.fuelPrice == cost ? color.opacity(0.15) : Color.clear)
                    .stroke(userSettings.fuelPrice == cost ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(userSettings.fuelPrice == cost ? color : .primary)
        }
        .buttonStyle(.plain)
    }
    
    private func presetInfo(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.bold())
            Text(desc)
                .font(.caption) // Reduced font size for description
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsFuelCostView(userSettings: UserSettings(includeGas: true))
    }
}
