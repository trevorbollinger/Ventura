//
//  SettingsMaintenanceView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/29/26.
//

import SwiftUI
import SwiftData

struct SettingsMaintenanceView: View {
    @Bindable var userSettings: UserSettings
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("Include Maintenance Estimate", isOn: $userSettings.includeMaintenance)
            } footer: {
               // Text("If enabled, this estimated cost will be deducted from your net profit calculation.")
            }
            
            if userSettings.includeMaintenance {
                Section("Cost Estimation") {
                    HStack {
                        Text("Cost per Mile")
                        Spacer()
                        TextField("Cost", value: $userSettings.maintenanceCostPerMile, format: .currency(code: "USD"))
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
                            presetButton(title: "Economy", cost: 0.08, color: .green)
                            presetButton(title: "Standard", cost: 0.10, color: .blue)
                            presetButton(title: "Heavy", cost: 0.15, color: .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The Invisible Cost of Driving")
                        .font(.headline)
                    
                    Text("While gas is a visible expense, every mile driven \"consumes\" a small portion of your vehicle's life. Tires wear down, oil breaks down, and parts eventually require replacement.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Industry experts like AAA estimate that maintenance and repairs cost approximately $0.08 to $0.12 per mile for the average passenger vehicle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("By including this cost, you get a \"True Net\" view of your earnings. This ensures that when it’s time for new tires or an oil change, that money has already been accounted for in your business math rather than coming out of your \"profit.\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if userSettings.includeMaintenance {
                 Section("Preset Guide") {
                     VStack(alignment: .leading, spacing: 12) {
                         presetInfo(title: "Economy ($0.08/mile)", desc: "For newer, highly reliable small cars (e.g., Prius, Corolla).")
                         presetInfo(title: "Standard ($0.10/mile)", desc: "The recommended baseline for most delivery vehicles.")
                         presetInfo(title: "Heavy Duty ($0.15/mile)", desc: "For older vehicles, SUVs, or regions with harsh winters/poor roads that accelerate wear.")
                     }
                     .padding(.vertical, 4)
                 }
            }
        }
        .navigationTitle("Maintenance Config")
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
            userSettings.maintenanceCostPerMile = cost
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
                    .fill(userSettings.maintenanceCostPerMile == cost ? color.opacity(0.15) : Color.clear)
                    .stroke(userSettings.maintenanceCostPerMile == cost ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(userSettings.maintenanceCostPerMile == cost ? color : .primary)
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
        SettingsMaintenanceView(userSettings: UserSettings(includeMaintenance: true))
    }
}
