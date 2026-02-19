//
//  DarkGradientBackground.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/4/26.
//

import SwiftUI

struct DarkGradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color("MidnightBackground"),
                Color("DeepGreyBackground")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        DarkGradientBackground()
            .ignoresSafeArea()
            
        VStack(spacing: 20) {
            Text("Dark Gradient")
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
