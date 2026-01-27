//
//  DashboardView.swift
//  DeliveryDriver
//
//  Created by Trevor Bollinger on 1/27/26.
//


import SwiftUI
import CoreLocation

struct DashboardView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Motion status 
            VStack(spacing: 10) {
                Text("VEHICLE IN MOTION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text(permissionManager.isMoving ? "YES" : "NO")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundColor(permissionManager.isMoving ? .green : .red)
            }
            
            Text(permissionManager.motionStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Permission buttons 
            VStack(spacing: 12) {
                if permissionManager.locationStatus == .notDetermined {
                    Button("Request Location Permissions") {
                        permissionManager.requestLocationPermission()
                        permissionManager.requestBackgroundLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if permissionManager.motionPermissionStatus != "Authorized" {
                    Button("Enable Motion Tracking") {
                        permissionManager.requestMotionPermission()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 30)
        }
        .padding()
    }
    
    private var locationStatusString: String {
        switch permissionManager.locationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

struct PermissionRow: View {
    let title: String
    let status: String
    let isGranted: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}

#Preview {
    DashboardView()
}
