//
//  MessageBubble.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//
import SwiftUI

struct MessageBubble: View {
    let entry: ConversationEntry
    var onBotMessageClick: ((String) -> Void)?

    var isHuman: Bool { entry.sender == .human }

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 40) }
            VStack {
                bubble
                    .frame(
                        maxWidth: 520,
                        alignment: isHuman ? .trailing : .leading
                    )
                if !isHuman {
                    if let handler = onBotMessageClick {
                        Button(
                            action: {
                                handler(entry.text)
                            },
                            label: { Label("Accept", systemImage: "checkmark") }
                        )
                        .frame(
                            alignment: .leading
                        )
                        .glassEffect(.regular.tint(.green).interactive())

                    }
                }

                Spacer(minLength: 40)
            }
        }
    }

    private var bubble: some View {
        Text(entry.text)
            .textSelection(.enabled)
            .font(.body)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(isHuman ? .white : .primary)
            .glassEffect(
                .regular.tint(isHuman ? .blue : .secondary.opacity(0.2))
                    .interactive(),
                in: .rect(cornerRadius: 16.0)
            )
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            .transition(
                .move(edge: isHuman ? .trailing : .leading).combined(
                    with: .opacity
                )
            )
    }
}
