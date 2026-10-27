//
//  AIMessage.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

struct MovingGradientForeground: ViewModifier {
    let colors: [Color]
    let duration: Double

    init(
        colors: [Color] = [.orange, .pink, .blue, .purple, .orange],
        duration: Double = 5
    ) {
        self.colors = colors
        self.duration = duration
    }

    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                AngularGradient(colors: colors,
                                center: .center,
                                angle: .degrees(angle))
                    .opacity(0.95)
                    .allowsHitTesting(false)
            }
            .mask {
                content
            }
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
    let message: LocalizedStringResource
    let font: Font

    var body: some View {
        AIMessageLabel(message: message, font: font)
            .animatedAIGradient()
    }
}

private struct AIMessageLabel: View {
    let message: LocalizedStringResource
    let font: Font

    var body: some View {
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
}
