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
            bubble
                .frame(maxWidth: 520, alignment: .center)
            Spacer(minLength: 40)
        }
    }

    private var bubble: some View {
        Label(text, systemImage: "apple.intelligence")
            .fontDesign(.monospaced)
            .padding()
            .border(Color.primary.opacity(0.25), width: 2)
            .textSelection(.enabled)
            .font(.body)
            .cornerRadius(8)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(.primary)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            .animatedAIGradient()
            .lineLimit(4)
            .truncationMode(.tail)
    }
}
