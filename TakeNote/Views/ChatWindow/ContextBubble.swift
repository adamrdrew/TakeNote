//
//  ContextBubble.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import SwiftUI

struct ContextBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 40)
            ContextBubbleContent(text: text)
                .frame(maxWidth: 520, alignment: .center)
            Spacer(minLength: 40)
        }
    }
}

private struct ContextBubbleContent: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "apple.intelligence")
            .fontDesign(.monospaced)
            .padding()
            .textSelection(.enabled)
            .font(.body)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(.primary.opacity(0.25), lineWidth: 2)
            )
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            .animatedAIGradient()
            .lineLimit(4)
            .truncationMode(.tail)
    }
}
