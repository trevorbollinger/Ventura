//
//  SettingsWageView.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/29/26.
//

import SwiftUI
import SwiftData

struct SettingsWageView: View {
    @Bindable var userSettings: UserSettings
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack (spacing: 10){
            Picker("Wage Model", selection: $userSettings.wageType) {
                ForEach(WageType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .padding(.horizontal)
            .pickerStyle(.segmented)
            .id("WagePicker")
            .animation(nil, value: userSettings.wageType)
            
            Text(wageDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Form {
                
                
                if userSettings.wageType != .none {
                    Section {
                        HStack {
                            Text(userSettings.wageType == .split ? "Driving Rate" : "Hourly Rate")
                            Spacer()
                            TextField("Wage", value: $userSettings.hourlyWage, format: .currency(code: "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                                .focused($isFocused)
                        }
                        
                        if userSettings.wageType == .split {
                            HStack {
                                Text("In-Store Rate")
                                Spacer()
                                TextField("Wage", value: $userSettings.passiveWage, format: .currency(code: "USD"))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                                    .focused($isFocused)
                            }
                        }
                    } header: {
                        Text("Rates")
                    } footer: {
                        if userSettings.wageType == .split {
                            Text("Driving Rate applies while on the road. In-Store Rate applies while at the store/restaurant.")
                        }
                    }
                }
                
//                Section {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Understanding Wages")
//                            .font(.headline)
//                        
//                        Text("Doordash Earn by Time not supported.\nUse 'Hourly' if you are paid the same in-store as on the road.\nUse 'Split' if you are paid a different rate when driving.")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                }
            }
            .navigationTitle("Hourly Wage")
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
    
    var wageDescription: String {
        switch userSettings.wageType {
        case .hourly:
            return "You are paid a flat hourly rate regardless of activity."
        case .split:
            return "You have different rates for driving vs. in-store time."
        case .none:
            return "You rely solely on tips and delivery fees (no hourly base pay)."
        }
    }
}

#Preview {
    NavigationStack {
        SettingsWageView(userSettings: UserSettings(hourlyWage: 15, passiveWage: 10, wageType: .split))
    }
}
