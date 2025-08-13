//
//  AIMessage.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

// Reusable animated gradient you can slap on any view's foreground
struct MovingGradientForeground: ViewModifier {
    var colors: [Color] = [.orange, .pink, .blue, .purple, .orange] // loop nicely
    var duration: Double = 5

    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                AngularGradient(colors: colors,
                                center: .center,
                                angle: .degrees(angle))
                    .opacity(0.95) // tame it a touch; tweak to taste
                    .allowsHitTesting(false)
            )
            .mask(content)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

extension View {
    func animatedAIGradient(
        colors: [Color] = [.orange, .pink, .blue, .purple, .orange],
        duration: Double = 5
    ) -> some View {
        modifier(MovingGradientForeground(colors: colors, duration: duration))
    }
}

struct AIMessage: View {
    var message: String
    var font: Font

    private var label: some View {
        Label {
            Text(message)
                .font(font)
                .lineLimit(2)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "apple.intelligence")
                .symbolRenderingMode(.hierarchical)
        }
        .symbolEffect(.bounce.down)
        .symbolEffect(.rotate)
    }

    var body: some View {
        // base is drawn once; gradient animates on top, masked to the label shape
        label
            .animatedAIGradient() // ← the magic
    }
}

