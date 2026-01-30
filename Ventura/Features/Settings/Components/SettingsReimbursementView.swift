//
//  SettingsReimbursementView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/29/26.
//

import SwiftUI
import SwiftData

struct SettingsReimbursementView: View {
    @Bindable var userSettings: UserSettings
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack (spacing: 10){
            Picker("Reimbursement Type", selection: $userSettings.reimbursementType) {
                ForEach(ReimbursementType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .padding(.horizontal)
            
            .pickerStyle(.segmented)
            .id("ReimbursementPicker")
            .animation(nil, value: userSettings.reimbursementType)
            
            Text(reimbursementDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Form {
               
                
                if userSettings.reimbursementType != .none {
                    Section("Rate") {
                        HStack {
                            Text(userSettings.reimbursementType == .perDelivery ? "Amount per Delivery" : "Amount per Mile")
                            Spacer()
                            TextField("Rate", value: $userSettings.reimbursement, format: .currency(code: "USD"))
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
                            
                            if userSettings.reimbursementType == .perMile {
                                HStack(spacing: 12) {
                                    presetButton(title: "Low", cost: 0.30, color: .orange)
                                    presetButton(title: "Standard", cost: 0.50, color: .blue)
                                    presetButton(title: "IRS (2024)", cost: 0.67, color: .green)
                                }
                            } else {
                                HStack(spacing: 12) {
                                    presetButton(title: "Low", cost: 1.50, color: .orange)
                                    presetButton(title: "Standard", cost: 2.50, color: .blue)
                                    presetButton(title: "High", cost: 4.00, color: .green)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reimbursements")
                            .font(.headline)
                        
                        Text("If you're reimbursed per mile, this amount will be automatically added if you have GPS enabled. ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("If you're reimbursed per delivery, this amount will be added as you report deliveries while driving or after a session.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Select 'None' for contracted services like Doordash where each delivery is a different payment. These will be reported separately.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Reimbursement")
            .onChange(of: userSettings.reimbursementType) { oldValue, newValue in
                // Auto-populate defaults when switching types
                if newValue == .perMile {
                    userSettings.reimbursement = 0.50
                } else if newValue == .perDelivery {
                    userSettings.reimbursement = 2.50
                }
            }
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
    }
    
    private func presetButton(title: String, cost: Double, color: Color) -> some View {
        Button {
            userSettings.reimbursement = cost
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
                    .fill(userSettings.reimbursement == cost ? color.opacity(0.15) : Color.clear)
                    .stroke(userSettings.reimbursement == cost ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(userSettings.reimbursement == cost ? color : .primary)
        }
        .buttonStyle(.plain)
    }

    var reimbursementDescription: String {
        switch userSettings.reimbursementType {
        case .perMile:
            return "You are paid a specific amount for every mile driven."
        case .perDelivery:
            return "You receive a flat fee for each delivery completed."
        case .none:
            return "You do not receive any specific vehicle reimbursement."
        }
    }
}

#Preview {
    NavigationStack {
        SettingsReimbursementView(userSettings: UserSettings(reimbursement: 0.50, reimbursementType: .perMile))
    }
}
