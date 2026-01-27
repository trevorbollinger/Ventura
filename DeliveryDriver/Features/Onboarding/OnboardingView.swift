//
//  OnboardingView.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI
import CoreLocation
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var currentIndex: Int
    @State private var selectedDriverType: DriverType?
    
    // Business Profile State
    @State private var mpg: Double = 24.0
    @State private var wage: Double = 15.0
    @State private var passiveWage: Double = 10.0
    @State private var reimbursement: Double = 0.50
    
    @State private var wageType: WageType = .hourly
    @State private var reimbursementType: ReimbursementType = .perMile

    init(initialPage: Int = 0) {
        _currentIndex = State(initialValue: initialPage)
    }
    
    @State private var dragOffset: CGFloat = 0
    @State private var screenWidth: CGFloat = 0

    private let totalPages = 4

    var currentProgress: CGFloat {
        let baseProgress = CGFloat(currentIndex)
        let dragProgress = screenWidth > 0 ? -dragOffset / screenWidth : 0
        return max(0, min(CGFloat(totalPages - 1), baseProgress + dragProgress))
    }

    var buttonColor: Color {
        let progress = currentProgress
        if progress < 1.0 {
            return Color.blue.interpolate(to: .purple, amount: progress)
        } else {
            return Color.purple.interpolate(to: .green, amount: progress - 1.0)
        }
    }

    var isLastPage: Bool {
        currentIndex == totalPages - 1
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Pages
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    WelcomePage()
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity)

                    PermissionsPage(permissionManager: permissionManager)
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity)
                        
                    TargetSelectionPage(selectedType: $selectedDriverType)
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity)
                        
                    BusinessProfilePage(mpg: $mpg, wage: $wage, passiveWage: $passiveWage, reimbursement: $reimbursement, wageType: $wageType, reimbursementType: $reimbursementType)
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                .onAppear {
                    screenWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    screenWidth = newWidth
                }
            }
            .padding(.bottom, 150) // Reserve space for controls

            // Controls (Indicators + Buttons)
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        let isActive = currentIndex == index
                        Capsule()
                            .foregroundColor(isActive ? .primary : .gray.opacity(0.5))
                            .frame(width: isActive ? 20 : 8, height: 8)
                    }
                }
                .animation(nil, value: currentIndex)
                
                // Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        if currentIndex > 0 {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentIndex -= 1
                                }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .frame(width: 50, height: 50)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button {
                            if isLastPage {
                                try? modelContext.delete(model: UserSettings.self)
                                let settings = UserSettings(
                                    driverType: selectedDriverType ?? .contractor,
                                    mpg: mpg,
                                    hourlyWage: wage,
                                    passiveWage: passiveWage,
                                    reimbursement: reimbursement,
                                    wageType: wageType,
                                    reimbursementType: reimbursementType
                                )
                                modelContext.insert(settings)
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentIndex += 1
                                }
                            }
                        } label: {
                            Text(buttonText)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(buttonColor)
                                )
                        }
                        .disabled((currentIndex == 2 || isLastPage) && selectedDriverType == nil)
                        .opacity((currentIndex == 2 || isLastPage) && selectedDriverType == nil ? 0.6 : 1.0)
                        // Make sure button animates its size change
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex) 
                    }
                    .padding(.horizontal, 40)

                    if currentIndex == 1 {
                        Button("Skip Setup") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                    } else if currentIndex < totalPages - 1 {
                        Button("Skip Setup") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                    } else {
                        Text("")
                            .font(.subheadline)
                            .frame(height: 20)
                    }
                }
//                .padding(.bottom, 25)
            }
            .background(
                LinearGradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .offset(y: 30)
                    .allowsHitTesting(false)
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.width < -threshold && currentIndex < totalPages - 1 {
                            currentIndex += 1
                        } else if value.translation.width > threshold && currentIndex > 0 {
                            currentIndex -= 1
                        }
                        dragOffset = 0
                    }
                }
        )
        #if os(iOS)
        .presentationDetents([.fraction(0.95)])
        .presentationDragIndicator(.hidden)
        #endif
    }
    
    var buttonText: String {
        switch currentIndex {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return "Continue"
        case 3: return "Finish Setup"
        default: return "Continue"
        }
    }
}





// MARK: - Individual Pages

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // "Net Profit" vs "Gross Pay" Graphic
            VStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 20) {
                    VStack {
                        Text("Gross Pay")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 120)
                    }
                    
                    VStack {
                        Text("Net Profit")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
                            )
                            .frame(width: 60, height: 150)
                    }
                }
                .padding()
            }

            VStack(spacing: 16) {
                Text("Drive smarter, not harder.")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Track every mile, tip, and expense automatically. No account needed—your data stays private on your iCloud.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

struct PermissionsPage: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 10) {
                Text("Enable the Auto-Pilot")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Please enable these permissions to track your mileage. Alternatively, you can enter your mileage manually.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            
            
            
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                // 1. Regular Location
                PermissionItem(
                    icon: "location.fill",
                    color: .blue,
                    title: "Precise Location",
                    description: "Tap 'Allow While Using App' first.",
                    buttonTitle: basicLocationButtonTitle,
                    isGranted: isBasicLocationGranted,
                    action: {
                        permissionManager.requestLocationPermission()
                    }
                )
                
                // 2. Background Location
                PermissionItem(
                    icon: "location.circle.fill",
                    color: .purple,
                    title: "Change to 'Always Allow'",
                    description: "Required to track mileage while your phone is locked.",
                    buttonTitle: backgroundLocationButtonTitle,
                    isGranted: isAlwaysLocationGranted,
                    isDisabled: !isBasicLocationGranted,
                    action: {
                        permissionManager.requestBackgroundLocationPermission()
                    }
                )
                
                // 3. Motion
                PermissionItem(
                    icon: "figure.run",
                    color: .orange,
                    title: "Motion & Fitness",
                    description: "To save battery by only using GPS when you are actually driving.",
                    buttonTitle: motionButtonTitle,
                    isGranted: permissionManager.motionPermissionStatus == "Authorized",
                    action: {
                        permissionManager.requestMotionPermission()
                    }
                )
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
    
    // Helpers
    var isBasicLocationGranted: Bool {
        permissionManager.locationStatus == .authorizedWhenInUse || permissionManager.locationStatus == .authorizedAlways
    }
    
    var isAlwaysLocationGranted: Bool {
        permissionManager.locationStatus == .authorizedAlways
    }
    
    var basicLocationButtonTitle: String {
        isBasicLocationGranted ? "Granted" : "Enable"
    }
    
    var backgroundLocationButtonTitle: String {
        isAlwaysLocationGranted ? "Granted" : "Enable"
    }
    
    var motionButtonTitle: String {
        permissionManager.motionPermissionStatus == "Authorized" ? "Granted" : "Enable"
    }
}

struct PermissionItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let buttonTitle: String
    let isGranted: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(isDisabled ? .gray : color)
                    .clipShape(Circle())
                    .opacity(isDisabled ? 0.3 : 1.0)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(isDisabled ? 0.5 : 1.0)
                }
                
                Spacer()
                
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                } else if isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Full-width button bar (only shown if not granted and not disabled)
            if !isGranted && !isDisabled {
                Button {
                    action()
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
    }
}

struct TargetSelectionPage: View {
    @Binding var selectedType: DriverType?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Who are you driving for?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("This helps us calibrate your tax and deduction logic.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 12) {
                ForEach(DriverType.allCases) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(type.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(selectedType == type ? .blue : .primary)
                                
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedType == type ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 2)
                                .background(selectedType == type ? Color.blue.opacity(0.05) : Color.clear)
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}



struct BusinessProfilePage: View {
    @Binding var mpg: Double
    @Binding var wage: Double
    @Binding var passiveWage: Double
    @Binding var reimbursement: Double
    @Binding var wageType: WageType
    @Binding var reimbursementType: ReimbursementType
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Set your baselines.")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("You can always change these later or per-shift.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)
                
                VStack(spacing: 24) {
                    // MPG Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average MPG")
                            .font(.headline)
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            
                            Text("\(Int(mpg)) mpg")
                                .font(.title3.bold())
                                .frame(width: 80, alignment: .leading)
                            
                            Stepper("", value: $mpg, in: 5...60, step: 1)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Hourly Wage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hourly Wage")
                            .font(.headline)
                        
                        Picker("Type", selection: $wageType) {
                            ForEach(WageType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if wageType != .none {
                            VStack(spacing: 10) {
                                // Active / Single Wage
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundStyle(.green)
                                        .frame(width: 30)
                                    
                                    Text(wageType == .split ? "Driving:" : "Rate:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    TextField("Wage", value: $wage, format: .currency(code: "USD"))
                                        .keyboardType(.decimalPad)
                                        .font(.title3.bold())
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                                .transition(.scale.combined(with: .opacity))
                                
                                // Passive Wage (Split only)
                                if wageType == .split {
                                    HStack {
                                        Image(systemName: "pause.circle.fill")
                                            .foregroundStyle(.gray)
                                            .frame(width: 30)
                                        
                                        Text("Idle:")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        TextField("Wage", value: $passiveWage, format: .currency(code: "USD"))
                                            .keyboardType(.decimalPad)
                                            .font(.title3.bold())
                                    }
                                    .padding()
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    
                    // Reimbursement
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reimbursement")
                            .font(.headline)
                        
                        Picker("Type", selection: $reimbursementType) {
                            ForEach(ReimbursementType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if reimbursementType != .none {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 30)
                                
                                TextField("Rate", value: $reimbursement, format: .currency(code: "USD"))
                                    .keyboardType(.decimalPad)
                                    .font(.title3.bold())
                                
                                Text(reimbursementType == .perDelivery ? "/ delivery" : "/ mile")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 100)
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.body.bold())
                    .tint(.blue)
                }
            }
        }
    }
}

// MARK: - Color Extension for Interpolation

extension Color {
    func interpolate(to color: Color, amount: CGFloat) -> Color {
        let amount = max(0, min(1, amount))

        guard let fromComponents = self.cgColor?.components,
            let toComponents = color.cgColor?.components
        else {
            return self
        }

        let r = fromComponents[0] + (toComponents[0] - fromComponents[0]) * amount
        let g = fromComponents[1] + (toComponents[1] - fromComponents[1]) * amount
        let b = fromComponents[2] + (toComponents[2] - fromComponents[2]) * amount

        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview("Onboarding View") {
    Text("Background View")
        .sheet(isPresented: .constant(true)) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
}

#Preview("Welcome Page") {
    Text("Background View")
        .sheet(isPresented: .constant(true)) {
            OnboardingView(initialPage: 0)
                .interactiveDismissDisabled()
        }
}

#Preview("Permissions Page") {
    Text("Background View")
        .sheet(isPresented: .constant(true)) {
            OnboardingView(initialPage: 1)
                .interactiveDismissDisabled()
        }
}

#Preview("Target Selection Page") {
    Text("Background View")
        .sheet(isPresented: .constant(true)) {
            OnboardingView(initialPage: 2)
                .interactiveDismissDisabled()
        }
}
