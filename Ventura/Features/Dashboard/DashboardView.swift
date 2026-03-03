import MapKit
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @State var graphViewModel = DashboardGraphViewModel()

    // Use cached settings from SessionManager — no @Query needed
    private var currentSettings: UserSettings {
        sessionManager.cachedSettings ?? UserSettings()
    }

    // MARK: - View
    var body: some View {
        NavigationStack {

            ScrollView {
                VStack(spacing: 16) {
//                    DashboardMapCard(settings: currentSettings)

                    DashboardGraphSection(
                        earningsPerHourData: graphViewModel.earningsPerHourData,
                        hoursWorkedData: graphViewModel.hoursWorkedData,
                        netEarningsData: graphViewModel.netEarningsData,
                        currencyCode: currentSettings.currencyCode
                    )
                }
                .padding()
                .padding(.bottom, 80)
            }
            .overlay(alignment: .bottom) {
                startSessionButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            .navigationTitle("Dashboard")

        }
        .task {
            graphViewModel.loadIfNeeded(
                container: modelContext.container,
                currencyCode: currentSettings.currencyCode
            )
        }
        .onChange(of: sessionManager.lastEndedSession) { _, _ in
            graphViewModel.refresh(
                container: modelContext.container,
                currencyCode: currentSettings.currencyCode
            )
        }
    }

    // MARK: - Components
    @ViewBuilder
    private var startSessionButton: some View {
        Button(action: {
            // Trigger the session start
            sessionManager.startSession()
            // In a real app, you might want to switch tabs here, but VenturaTabs handles it if bound right.
        }) {
            HStack {
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title)
                Text("Start Tracking")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Previews
#Preview("Dashboard") {
    let container = PreviewHelper.makeContainer()
    DashboardView(graphViewModel: PreviewHelper.mockDashboardGraphViewModel)
        .modelContainer(container)
        .environment(SessionManager())
}
