//
//  MessageBubble.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//
import SwiftData
import SwiftUI

// Three-dot typing indicator rendered inside a bot bubble while waiting for the first streaming token.
// Uses PhaseAnimator to cycle continuously through three phases (one leading dot per phase),
// producing a sequential wave: dot 0 pulses, then dot 1, then dot 2, then repeats.
// When reduceMotion is true, all dots render at uniform scale with no animation.
private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Each phase index (0, 1, 2) identifies which dot is currently at peak scale.
    private let phases: [Int] = [0, 1, 2]

    var body: some View {
        if reduceMotion {
            staticDots
        } else {
            PhaseAnimator(phases) { leadingDot in
                dotsRow(leadingDot: leadingDot)
            } animation: { _ in
                .easeInOut(duration: 0.4)
            }
        }
    }

    private var staticDots: some View {
        dotsRow(leadingDot: -1)
    }

    private func dotsRow(leadingDot: Int) -> some View {
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
    var onBotMessageClick: ((String) -> Void)?
    var notes: [Note] = []

    var isHuman: Bool { entry.sender == .human }

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 40) }

            // Constrain the whole message column
            VStack(alignment: isHuman ? .trailing : .leading, spacing: 6) {
                bubble
                    .frame(
                        maxWidth: .infinity,
                        alignment: isHuman ? .trailing : .leading
                    )

                if !isHuman && entry.isComplete, let handler = onBotMessageClick {
                    // Button hugs content and stays left under the 520px column
                    HStack(spacing: 0) {
 

                        
                        Button{  handler(entry.text)} label:  {
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
                    let uniqueSources = deduplicated(entry.sources)
                    if !uniqueSources.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(uniqueSources, id: \.noteID) { hit in
                                if let url = URL(string: "takenote://note/\(hit.noteID.uuidString)") {
                                    Link(noteTitle(for: hit.noteID), destination: url)
                                        .font(.caption)
                                        .foregroundStyle(Color.takeNotePink)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .frame(maxWidth: 520, alignment: isHuman ? .trailing : .leading)

            if !isHuman { Spacer(minLength: 40) }
        }
    }

    private func noteTitle(for noteID: UUID) -> String {
        notes.first(where: { $0.uuid == noteID })?.title ?? "Note"
    }

    private func deduplicated(_ hits: [SearchHit]) -> [SearchHit] {
        var seen = Set<UUID>()
        return hits.filter { seen.insert($0.noteID).inserted }
    }

    private var bubble: some View {
        Group {
            if !isHuman && entry.text.isEmpty && !entry.isComplete {
                // Waiting for first streaming token: show animated typing indicator inside the bubble.
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
                Text(entry.text)
                    .textSelection(.enabled)
                    .font(.body)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .foregroundColor(isHuman ? .white : .primary)
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
}
