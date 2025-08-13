//
//  ChatWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import FoundationModels
import SwiftData
import SwiftUI

enum Sender {
    case human
    case bot
}

struct ConversationEntry: Identifiable, Hashable {
    var id: UUID
    var sender: Sender
    var text: String

    init(sender: Sender, text: String) {
        self.id = UUID()
        self.sender = sender
        self.text = text
    }
}

struct ChatWindow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var search: SearchIndexService

    @State private var conversation: [ConversationEntry] = []
    @State private var userQuery: String = ""
    @State private var searchResults: [SearchIndex.SearchHit] = []
    @State private var responseIsGenerating: Bool = false

    @FocusState private var textFieldFocused: Bool

    // MARK: - Actions

    private func askQuestion() {
        let trimmed = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !responseIsGenerating else { return }

        responseIsGenerating = true

        let conversationEntry = ConversationEntry(sender: .human, text: trimmed)
        conversation.append(conversationEntry)

        // Prepare retrieval
        self.searchResults = search.index.searchNatural(trimmed)

        // Clear the field & keep focus
        self.userQuery = ""
        self.textFieldFocused = true

        Task { await generateResponse() }
    }

    private func makeConversationString() -> String {
        // Generate a log of the conversation and senders
        return conversation.map { entry in
            "\(entry.sender == .human ? "User" : "Assistant"): \(entry.text)"
        }.joined(separator: "\n")
    }

    private func makePrompt() -> String {
        var prompt = "Provide an answer to the following question:\n\n"
        prompt += "\(conversation.last?.text ?? "")\n\n"
        prompt += "SOURCE EXCERPTS:\n\n"
        for (index, result) in searchResults.enumerated() {
            prompt += "SOURCE EXCERPT \(index):\n \(result.chunk)\n\n"
        }
        prompt += "CHAT HISTORY:\n\n\(makeConversationString())\n\n"
        return prompt
    }

    private func generateResponse() async {
        let instructions =
            """
            You are a helpful notes assistant for a retrieval system.

            SCOPE
            - Answer from the provided SOURCE EXCERPTS.
            - Use CHAT HISTORY only to resolve context (pronouns, follow-ups, constraints, user intent). Do NOT treat it as evidence for facts.
            - Do not use outside/world knowledge.
            - If you can't find a direct answer to the question in the SOURCE EXERPTS use the information in them to infer what the right answer might be to the best of your ability

            AUTHORITY ORDER
            1) SOURCE EXCERPTS (highest authority)
            2) CHAT HISTORY (context only; not evidence)

            OUTPUT RULES
            - Be concise and accurate.
            - Do not mention sources, file names, or chat history in your answer.
            - No citations or meta-commentary.
            - Prefer a short paragraph; use bullets only when listing items.

            GROUNDING CHECK (silent; do not output)
            - Every factual claim must be directly supported by the SOURCE EXCERPTS.
            - Remove or soften any sentence not supported by the sources.
            - If sources conflict, reflect the uncertainty briefly without naming sources.

            FAILURE MODE
            - If nothing relevant is found, respond: “I couldn’t find that in your notes.” Optionally suggest a tighter query the user might try.

            """

        let session = LanguageModelSession(instructions: instructions)
        if session.isResponding { return }

        let prompt = makePrompt()
        let response = try? await session.respond(to: prompt)
        let aiSummary = response?.content ?? "—"

        responseIsGenerating = false
        let conversationEntry = ConversationEntry(sender: .bot, text: aiSummary)
        conversation.append(conversationEntry)
    }

    private func newChat() {
        conversation.removeAll()
        userQuery = ""
        responseIsGenerating = false
        textFieldFocused = true
    }

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversation) { entry in
                            MessageBubble(entry: entry)
                                .id(entry.id)
                                .padding(.horizontal, 12)
                                .padding(.top, 2)
                        }

                        // Subtle typing indicator when generating
                        if responseIsGenerating {
                            AIMessage(message: "Thinking...", font: .headline)
                        }

                        // Bottom spacer to anchor scroll
                        Color.clear.frame(height: 1).id("BOTTOM")
                    }
                    .padding(.vertical, 8)
                }
                .background(.background)
                .onChange(of: conversation.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                // Rounded, iMessage-like input
                HStack(spacing: 8) {
                    TextField("Ask anything", text: $userQuery, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($textFieldFocused)
                        .onSubmit(askQuestion)

                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(10)
            .background(.bar)  // blends like a toolbar at the bottom
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newChat()
                } label: {
                    Label("New Chat", systemImage: "plus.message")
                }
                .glassEffect()
            }
        }
        .onAppear { textFieldFocused = true }
    }
}
