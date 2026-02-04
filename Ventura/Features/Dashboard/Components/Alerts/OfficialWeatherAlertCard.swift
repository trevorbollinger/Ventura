//
//  OfficialWeatherAlertCard.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/2/26.
//

import SwiftUI

struct OfficialWeatherAlertCard: View {
    @EnvironmentObject var manager: WeatherManager
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 34
    
    var body: some View {
        // Filter out minor and moderate severity alerts (only show extreme/severe)
        let alerts = (manager.ui?.officialAlerts ?? [])
            .filter { 
                let severity = $0.severity.lowercased()
                return severity != "minor" && severity != "moderate"
            }
        
        if !alerts.isEmpty {
            VStack(spacing: 20) {
                ForEach(alerts, id: \.summary) { alert in
                    Link(destination: alert.detailsURL) {
                        HStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .center) {
                                    Text(alert.summary.uppercased())
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    Text(alert.severity.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.red.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundStyle(.red)
                                }
                                
                                HStack(alignment: .center, spacing: 4) {
                                    Text("Source: \(alert.source)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        )
                        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("Critical Alerts") {
    DashboardView()
        .onAppear {
            PreviewHelper.configureWeatherPreview(with: .criticalAll)
        }
}
