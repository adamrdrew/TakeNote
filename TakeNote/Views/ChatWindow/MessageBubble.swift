//
//  MessageBubble.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//
import SwiftUI
import os

private let messageBubbleLogger = Logger(
    subsystem: "com.adamdrew.takenote",
    category: "MessageBubble"
)

private func markdownAttributedString(_ text: String) -> AttributedString {
    do {
        return try AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    } catch {
        messageBubbleLogger.debug("Failed to parse chat message markdown: \(error.localizedDescription)")
        return AttributedString(text)
    }
}

private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phases: [Int] = [0, 1, 2]

    var body: some View {
        if reduceMotion {
            TypingIndicatorDots()
        } else {
            PhaseAnimator(phases) { leadingDot in
                TypingIndicatorDots(leadingDot: leadingDot)
            } animation: { _ in
                .easeInOut(duration: 0.4)
            }
        }
    }
}

private struct TypingIndicatorDots: View {
    let leadingDot: Int?

    init(leadingDot: Int? = nil) {
        self.leadingDot = leadingDot
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(i == leadingDot ? 1.4 : 1.0)
            }
        }
    }
}

struct MessageBubble: View {
    let entry: ConversationEntry
    let onBotMessageClick: ((String) -> Void)?

    init(
        entry: ConversationEntry,
        onBotMessageClick: ((String) -> Void)? = nil
    ) {
        self.entry = entry
        self.onBotMessageClick = onBotMessageClick
    }

    private var isHuman: Bool { entry.sender == .human }

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 40) }

            // Constrain the whole message column
            VStack(alignment: isHuman ? .trailing : .leading, spacing: 6) {
                MessageBubbleContent(
                    text: entry.text,
                    isHuman: isHuman,
                    isComplete: entry.isComplete
                )
                    .frame(
                        maxWidth: .infinity,
                        alignment: isHuman ? .trailing : .leading
                    )

                if !isHuman, let status = entry.toolCallStatus {
                    Label {
                        Text(status.message)
                    } icon: {
                        Image(systemName: status.iconName)
                    }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: entry.toolCallStatus)
                }

                if !isHuman && entry.isComplete, let handler = onBotMessageClick {
                    // Button hugs content and stays left under the 520px column
                    HStack(spacing: 0) {
                        Button {
                            handler(entry.text)
                        } label: {
                            Label("Accept", systemImage: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.background)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 3)
                        }
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Accept this suggestion")
                        .accessibilityHint("Accept the AI formatting suggestion")

                        Spacer(minLength: 0)
                    }
                }

                if !isHuman && entry.isComplete && !entry.sources.isEmpty {
                    MessageSourceLinks(hits: entry.sources)
                }
            }
            .frame(maxWidth: 520, alignment: isHuman ? .trailing : .leading)

            if !isHuman { Spacer(minLength: 40) }
        }
    }
}

private struct MessageSourceLinks: View {
    private struct SourceLink: Identifiable {
        let hit: SearchHit
        let destination: URL

        var id: UUID { hit.noteID }
    }

    let hits: [SearchHit]

    private var sourceLinks: [SourceLink] {
        var seen = Set<UUID>()
        return hits.compactMap { hit in
            guard seen.insert(hit.noteID).inserted else { return nil }
            guard let destination = URL(string: "takenote://note/\(hit.noteID.uuidString)") else {
                return nil
            }
            return SourceLink(hit: hit, destination: destination)
        }
    }

    var body: some View {
        if !sourceLinks.isEmpty {
            HStack(spacing: 6) {
                ForEach(sourceLinks) { sourceLink in
                    Link(sourceLink.hit.displayTitle, destination: sourceLink.destination)
                        .font(.caption)
                        .foregroundStyle(Color.takeNotePink)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        }
    }

}

private struct MessageBubbleContent: View {
    let text: String
    let isHuman: Bool
    let isComplete: Bool

    var body: some View {
        if !isHuman && text.isEmpty && !isComplete {
            TypingIndicator()
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            #if !os(visionOS)
                .glassEffect(
                    .regular.tint(.secondary.opacity(0.2)).interactive(),
                    in: .rect(cornerRadius: 16.0)
                )
            #endif
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                .transition(
                    .move(edge: .leading).combined(with: .opacity)
                )
        } else {
            Text(markdownAttributedString(text))
                .textSelection(.enabled)
                .font(.body)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .foregroundStyle(isHuman ? .white : .primary)
            #if !os(visionOS)
                .glassEffect(
                    .regular.tint(isHuman ? .takeNotePink : .secondary.opacity(0.2))
                        .interactive(),
                    in: .rect(cornerRadius: 16.0)
                )
            #endif
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                .transition(
                    .move(edge: isHuman ? .trailing : .leading).combined(
                        with: .opacity
                    )
                )
        }
    }
}
