//
//  MeshGradientBackground.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI

struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Top-left light blue blob
                Circle()
                    .fill(Color("LightBlueGradient"))
                    .frame(width: geometry.size.width * 1.2, height: geometry.size.width * 1.2)
                    .blur(radius: 100)
                    .offset(
                        x: animate ? -geometry.size.width * 0.3 : -geometry.size.width * 0.2,
                        y: animate ? -geometry.size.height * 0.2 : -geometry.size.height * 0.15
                    )
                
                // Bottom-right dark blue blob
                Circle()
                    .fill(Color("DarkBlueGradient"))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .blur(radius: 100)
                    .offset(
                        x: animate ? geometry.size.width * 0.3 : geometry.size.width * 0.2,
                        y: animate ? geometry.size.height * 0.3 : geometry.size.height * 0.25
                    )
                
                // Center light blue blob
                Circle()
                    .fill(Color("LightBlueGradient"))
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                    .blur(radius: 100)
                    .offset(
                        x: animate ? geometry.size.width * 0.1 : 0,
                        y: animate ? -geometry.size.height * 0.05 : 0
                    )
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

#Preview {
    ZStack {
        MeshGradientBackground()
            .ignoresSafeArea()
            
        VStack(spacing: 20) {
            Text("Mesh Gradient")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Glass Card Example")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Content sits on top of the background with a blur effect.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        }
        .padding()
    }
}
