//
//  SettingsView.swift
//  Ventura
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
            
            Section("Home Location") {
                NavigationLink {
                    SettingsHomeLocationEditView(userSettings: userSettings)
                } label: {
                    HStack {
                        Label(userSettings.homeName ?? "Home Location", systemImage: userSettings.homeIcon ?? "house.fill")
                        Spacer()
                        Text(userSettings.homeAddress ?? "Not Set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Section("Business Profile") {

                
                NavigationLink {
                    SettingsFuelCostView(userSettings: userSettings)
                } label: {
                    HStack {
                        Text("Fuel")
                        Spacer()
                        if userSettings.includeGas {
                            Text("\(userSettings.fuelPrice.formatted(.currency(code: "USD")))/gal • \(userSettings.mpg.formatted()) mpg")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    SettingsMaintenanceView(userSettings: userSettings)
                } label: {
                    HStack {
                        Text("Maintenance")
                        Spacer()
                        if userSettings.includeMaintenance {
                            Text(userSettings.maintenanceCostPerMile.formatted(.currency(code: "USD")) + "/mi")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    SettingsWageView(userSettings: userSettings)
                } label: {
                    HStack {
                        Text("Hourly Wage")
                        Spacer()
                        if userSettings.wageType == .none {
                            Text("None")
                                .foregroundStyle(.secondary)
                        } else if userSettings.wageType == .split {
                            Text("\(userSettings.hourlyWage.formatted(.currency(code: "USD"))) • \(userSettings.passiveWage.formatted(.currency(code: "USD"))) /hr")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(userSettings.hourlyWage.formatted(.currency(code: "USD")) + "/hr")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    SettingsReimbursementView(userSettings: userSettings)
                } label: {
                    HStack {
                        Text("Reimbursement")
                        Spacer()
                        if userSettings.reimbursementType == .none {
                            Text("None")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(userSettings.reimbursement.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
//            Section {
//                Toggle("Debug Mode", isOn: $userSettings.isDebugMode)
//            } header: {
//                Text("Developer Settings")
//            } footer: {
//                Text("Enables advanced tracking diagnostics and raw data indicators on the dashboard.")
//            }
            
            Section {
                NavigationLink("About") {
                    AboutView()
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
    let container = PreviewHelper.makeEmptyContainer()
    return SettingsView()
        .modelContainer(container)
}
