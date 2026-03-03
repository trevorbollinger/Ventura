//
//  ManageTipsSheet.swift
//  Ventura
//

import SwiftUI

struct ManageTipsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var sessionManager

    @State private var showAddTipSheet = false
    @State private var editingTipIndex: Int? = nil

    private var tips: [Decimal] {
        sessionManager.activeSession?.tips ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if tips.isEmpty {
                    ContentUnavailableView(
                        "No Tips Yet",
                        systemImage: "dollarsign.circle",
                        description: Text("Tap the + button to log a delivery tip.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(tips.indices, id: \.self) { index in
                                HStack {
                                    Label("Tip #\(index + 1)", systemImage: "dollarsign.circle.fill")
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button {
                                        editingTipIndex = index
                                    } label: {
                                        Text(tips[index].formatted(.currency(code: "USD")))
                                            .font(.body.monospacedDigit().bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)

                                    Button(role: .destructive) {
                                        sessionManager.removeTip(at: index)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text("\(tips.count) Deliveries")
                        } footer: {
                            HStack {
                                Text("Total Tips")
                                Spacer()
                                Text(tips.reduce(Decimal(0), +).formatted(.currency(code: "USD")))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Manage Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTipSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTipSheet) {
                LogDeliverySheet { amount, countAsDelivery in
                    sessionManager.addTip(amount, countAsDelivery: countAsDelivery)
                }
            }
            .sheet(item: Binding(
                get: { editingTipIndex.map { IdentifiableInt(id: $0) } },
                set: { editingTipIndex = $0?.id }
            )) { item in
                LogDeliverySheet(initialValue: tips[item.id], isEditing: true) { amount, _ in
                    sessionManager.editTip(at: item.id, newAmount: amount)
                }
            }
        }
    }
}
