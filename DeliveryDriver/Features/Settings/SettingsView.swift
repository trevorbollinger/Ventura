//
//  SettingsView.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    var body: some View {
        NavigationStack {
            if let userSettings = settings.first {
                SettingsForm(userSettings: userSettings)
            } else {
                ContentUnavailableView {
                    Label("No Profile Found", systemImage: "person.slash")
                } description: {
                    Text("Complete the onboarding to create your profile.")
                } actions: {
                    Button("Create Default Profile") {
                        try? modelContext.delete(model: UserSettings.self)
                        let newSettings = UserSettings()
                        modelContext.insert(newSettings)
                    }
                }
                .navigationTitle("Settings")
            }
        }
    }
}

struct SettingsForm: View {
    @Bindable var userSettings: UserSettings
    @FocusState private var isFocused: Bool
    
    var body: some View {
        List {
            Section {
                Picker("Employment Type", selection: $userSettings.driverType) {
                    ForEach(DriverType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            } header: {
                Text("Driver Profile")
            } footer: {
                Text("This setting helps calibrate your tax and deduction logic.")
            }
            
            Section("Business Profile") {
                HStack {
                    Text("Average MPG")
                    Spacer()
                    Text("\(Int(userSettings.mpg)) mpg")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $userSettings.mpg, in: 5...60, step: 1)
                        .labelsHidden()
                }
                
                Picker("Hourly Wage", selection: $userSettings.wageType) {
                    ForEach(WageType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if userSettings.wageType != .none {
                    HStack {
                        Text(userSettings.wageType == .split ? "Driving Rate" : "Rate")
                        Spacer()
                        TextField("Wage", value: $userSettings.hourlyWage, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .focused($isFocused)
                    }
                    
                    if userSettings.wageType == .split {
                        HStack {
                            Text("Idle Rate")
                            Spacer()
                            TextField("Wage", value: $userSettings.passiveWage, format: .currency(code: "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .focused($isFocused)
                        }
                    }
                }
                
                Picker("Reimbursement", selection: $userSettings.reimbursementType) {
                    ForEach(ReimbursementType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if userSettings.reimbursementType != .none {
                    HStack {
                        Text(userSettings.reimbursementType == .perDelivery ? "Rate / delivery" : "Rate / mile")
                        Spacer()
                        TextField("Rate", value: $userSettings.reimbursement, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .focused($isFocused)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                    .font(.body.bold())
                    .tint(.blue)
                }
            }
            
            if isFocused {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isFocused = false
                    }
                    .font(.body.bold())
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
