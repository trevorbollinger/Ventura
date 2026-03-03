//
//  LogDeliverySheet.swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/27/26.
//

import SwiftUI

struct LogDeliverySheet: View {
    @Environment(\.dismiss) private var dismiss
    var initialValue: Decimal? = nil
    var isEditing: Bool = false
    var onSave: (Decimal, Bool) -> Void

    @State private var inputString: String = ""
    @State private var countAsDelivery: Bool = true  // Default to true for "Log Delivery"
    
    init(initialValue: Decimal? = nil, isEditing: Bool = false, onSave: @escaping (Decimal, Bool) -> Void) {
        self.initialValue = initialValue
        self.isEditing = isEditing
        self.onSave = onSave
        
        if let initial = initialValue {
            _inputString = State(initialValue: "\(initial)")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 15) {
                Spacer()

                // Display Value
                Text("TIP AMOUNT")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundStyle(.secondary.opacity(0.8))

                Text(displayString)
                    .font(
                        .system(size: 60, weight: .bold, design: .rounded)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        inputString.isEmpty
                            ? AnyShapeStyle(.secondary.opacity(0.5))
                            : AnyShapeStyle(.primary)
                    )
                    .lineLimit(1)
                    .padding(.horizontal)
                    .contentShape(Rectangle())



                Spacer()

                // Custom Keypad
                KeypadView { key in
                    handleKeyPress(key)
                }

//                // Count as Delivery Toggle
//                if !isEditing {
//                    Toggle(isOn: $countAsDelivery) {
//                        Text("Count as Delivery")
//                            .font(.headline)
//                            .foregroundStyle(.primary)
//                    }
//                    .tint(.green)
//
//                    .padding(.horizontal)
//                    .padding(.vertical)
//                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 32))
//                    .padding(.horizontal)
//                }
//                Spacer()

            }

            //                .padding(.top, 15)

            .navigationTitle(isEditing ? "Edit Tip" : "Log Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Decimal(string: inputString) {
                            let tip = value
                            onSave(tip, countAsDelivery)
                            dismiss()
                        } else if inputString.isEmpty {
                            onSave(0, countAsDelivery)
                            dismiss()
                        }
                    }
                    .font(.headline)
                    .disabled(
                        (!countAsDelivery
                            && (Decimal(string: inputString) ?? 0) == 0)
                    )
                }
            }
        }
        #if os(iOS)
            .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.visible)
        #endif
    }

    private var displayString: String {
        if inputString.isEmpty {
            return "$0"
        }
        return "$" + inputString
    }

    private func handleKeyPress(_ key: String) {
        if key == "delete" {
            if !inputString.isEmpty {
                inputString.removeLast()
            }
        } else if key == "." {
            if inputString.isEmpty {
                inputString = "0."
            } else if !inputString.contains(".") {
                inputString.append(".")
            }
        } else {
            if inputString == "0" && key != "." {
                inputString = key
            } else {
                if let decimalIndex = inputString.firstIndex(of: ".") {
                    let distance = inputString.distance(
                        from: decimalIndex,
                        to: inputString.endIndex
                    )
                    if distance <= 2 {
                        inputString.append(key)
                    }
                } else {
                    inputString.append(key)
                }
            }
        }
    }
}

// MARK: - Keypad Components

struct KeypadView: View {
    let action: (String) -> Void

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { num in
                KeypadButton(text: "\(num)") {
                    action("\(num)")
                }

            }

            KeypadButton(text: ".") {
                action(".")
            }

            KeypadButton(text: "0") {
                action("0")
            }

            KeypadButton(imageName: "chevron.left") {
                action("delete")
            }
        }

        .padding(.horizontal, 20)

    }
}

struct KeypadButton: View {
    var text: String?
    var imageName: String?
    var action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack {
                if let text = text {
                    Text(text)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                } else if let imageName = imageName {
                    Image(systemName: imageName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())

        }

        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isShowing = true
        var body: some View {
            Color.clear
                .sheet(isPresented: $isShowing) {
                    LogDeliverySheet { _, _ in }
                        .presentationDetents([.fraction(0.75)])
                }
        }
    }
    return PreviewWrapper()
}
