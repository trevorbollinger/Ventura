//
//  .swift
//  Ventura
//
//  Created by Trevor Bollinger on 1/30/26.
//


import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack {
            Spacer()
            // Header
            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(radius: 10)

                VStack {
                    Text("Ventura")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    HStack(spacing: 3) {
                        Text(versionString)
                            .font(.caption)
                        Text("(\(buildString))")
                            .font(.caption)
                    }
                }
            }

            Spacer()

            VStack {
                HStack {
                    Text("Support and Feedback:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack {
                    Button(action: {
                        if let url = URL(string: "mailto:trevor@boli.dev") {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                            Text("trevor@boli.dev")
                                .underline()
                                .font(.subheadline)
                                .bold()
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.blue.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 5)
                    
                    Spacer()
                }
            }
            .padding()
            
            // Premium Button (Placeholder)
            Button(action: { }) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Upgrade to Premium")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.horizontal)
            }
            .padding(.vertical, 15)

            // Donation Buttons (Placeholder)
            HStack {
                Button(action: { }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Donate $2")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Donate $5")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Text("If you enjoy the app, consider donating to help cover the developer fee and keep the app on the App Store!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
                .padding(.horizontal)

            Spacer()
            
            HStack(alignment: .center) {
                Image("boli")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(30)

                Text("Boli Development")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    AboutView()
}
