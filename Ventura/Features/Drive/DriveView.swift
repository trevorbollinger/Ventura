import SwiftUI
import MapKit
import SwiftData

// MARK: - Preference Keys for Dynamic Safe Area Insets
private struct TopInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BottomInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct DriveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var sessionManager
    
    // We fetch current settings from the cache to prevent @Query DB re-renders.
    private var userSettings: UserSettings { sessionManager.cachedSettings ?? UserSettings() }
    
    // UI State variables
    @State private var showTipSheet = false
    @State private var showManageTipsSheet = false
    @State private var showEndAlert = false
    @State private var cameraResetTrigger = 0
    @State private var isFollowingUser = true
    @State private var startStopTrigger = false
    
    // Map scope for externally-placed map controls
    @Namespace private var mapScope
    
    // Measured overlay heights for dynamic map centering
    @State private var topInset: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    
    var activeSession: Session? {
        sessionManager.activeSession
    }
    
    // MARK: - Body View
    var body: some View {
        ZStack {
            // 1. Map Layer
            DriveMap(
                route: sessionManager.liveRoute,
                cameraResetTrigger: cameraResetTrigger,
                isFollowingUser: $isFollowingUser,
                homeLocation: userSettings.homeLatitude.flatMap { lat in
                    userSettings.homeLongitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) }
                },
                homeRadius: userSettings.homeRadius,
                homeName: userSettings.homeName ?? "Home",
                homeIcon: userSettings.homeIcon ?? "house.fill",
                scope: mapScope,
                topInset: topInset,
                bottomInset: bottomInset
            )
            
            // 2. Control Layout Overlay
            VStack(spacing: 0) {
                // Top Section — measured for dynamic safe area
                VStack(spacing: 0) {
                    // Header (Stats)
                    DriveSessionHeader(
                        tickerState: sessionManager.activeSessionState,
                        settings: userSettings
                    )
                    .padding(.horizontal)

                    // Top Controls Row
                    HStack {
                        
                        //WEATHER PILL
                        
                        //GAS BUTTON
                        
                        Button {
                            showManageTipsSheet = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .glassModifier(in: Circle())
                        }
                        
                        Spacer()

                        Button {
                            showTipSheet = true
                        } label: {
                                Label(
                                    "Delivery",
                                    systemImage: "plus.circle.fill"
                                )
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .glassModifier(
                                    in: RoundedRectangle(cornerRadius: 20)
                                )
                            }
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 7)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TopInsetKey.self, value: geo.size.height)
                    }
                )
                
                Spacer()
                
                // Footer — End button with map controls stacked on the right
                VStack(spacing: 12) {
                   
                    
                    // Map Controls — stacked vertically on the right
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 10) {
                            MapCompass(scope: mapScope)
                                .mapControlVisibility(.visible)
                            
                            Button {
                                cameraResetTrigger += 1
                                isFollowingUser = true
                            } label: {
                                Image(systemName: isFollowingUser ? "location.fill" : "location")
                                    .font(.title3)
                                    .foregroundStyle(isFollowingUser ? .blue : .secondary)
                                    .frame(width: 44, height: 44)
                                    .glassModifier(in: Circle())
                            }
                        }
                    }
                    
                    
                    // End Session Button
                    Button {
                        showEndAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("End Session")
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.red)
                        .cornerRadius(20)
                        .glassModifier(
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                    }
                    .sensoryFeedback(.success, trigger: startStopTrigger)
                    .confirmationDialog(
                        "End Session?",
                        isPresented: $showEndAlert,
                        titleVisibility: .visible
                    ) {
                        Button("End Session", role: .destructive) {
                            startStopTrigger.toggle()
                            sessionManager.stopSession()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "Are you sure you want to end your current session?"
                        )
                    }
                    
                }
                .padding(.horizontal)
            }
        }
        .mapScope(mapScope)
        .onPreferenceChange(TopInsetKey.self) { topInset = $0 }
        .onPreferenceChange(BottomInsetKey.self) { bottomInset = $0 }

        
        // Modal sheets
        .sheet(isPresented: $showTipSheet) {
            LogDeliverySheet { amount, countAsDelivery in
                sessionManager.addTip(
                    amount,
                    countAsDelivery: countAsDelivery
                )
            }
        }
        .sheet(isPresented: $showManageTipsSheet) {
            ManageTipsSheet()
        }

    }
}

// MARK: - Previews

#Preview("Drive View") {
    let container = PreviewHelper.makeContainer()
    DriveView()
        .modelContainer(container)
        .environment(PreviewHelper.mockSessionManager)
}

#Preview("Drive View – No Home") {
    let container = PreviewHelper.makeContainerNoHome()
    DriveView()
        .modelContainer(container)
        .environment(PreviewHelper.mockSessionManagerNoHome)
}
