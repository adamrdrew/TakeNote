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
    @Environment(SearchIndexService.self) private var search

    @State private var conversation: [ConversationEntry] = []
    @State private var userQuery: String = ""
    @State private var searchResults: [SearchHit] = []
    @State private var responseIsGenerating: Bool = false

    var context: String?
    var instructions: String?
    var prompt: String?
    var searchEnabled: Bool = true
    var onBotMessageClick: ((String) -> Void)?
    var toolbarVisible: Bool = true
    var useHistory: Bool = true

    @FocusState private var textFieldFocused: Bool


    // MARK: - Actions

    private func askQuestion() {
        let trimmed = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !responseIsGenerating else { return }

        responseIsGenerating = true

        let conversationEntry = ConversationEntry(sender: .human, text: trimmed)
        conversation.append(conversationEntry)

        // Prepare retrieval
        if searchEnabled {
            self.searchResults = search.index.searchNatural(trimmed)
        }

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
        var llmPrompt =
            prompt ?? "Provide an answer to the following question:\n\n"
        llmPrompt += "\(conversation.last?.text ?? "")\n\n"
        if context != nil {
            llmPrompt += "CONTEXT: \n\(context ?? "")\n\n"
        }
        if searchEnabled {
            llmPrompt += "SOURCE EXCERPTS:\n\n"
            for (index, result) in searchResults.enumerated() {
                llmPrompt += "SOURCE EXCERPT \(index):\n \(result.chunk)\n\n"
            }
        }
        if useHistory {
            llmPrompt += "CHAT HISTORY:\n\n\(makeConversationString())\n\n"
        }
        return llmPrompt
    }

    private func generateResponse() async {
        guard SystemLanguageModel.default.availability == .available else {
            responseIsGenerating = false
            conversation.append(ConversationEntry(sender: .bot, text: "Apple Intelligence is not available on this device."))
            return
        }

        let modelInstructions = instructions ?? MAGIC_CHAT_PROMPT

        let session = LanguageModelSession(instructions: modelInstructions)
        if session.isResponding { return }

        let assembledPrompt = makePrompt()
        let response = try? await session.respond(to: assembledPrompt)
        let aiSummary = response?.content ?? "Something went wrong. Sorry."

        responseIsGenerating = false
        let conversationEntry = ConversationEntry(sender: .bot, text: unwrapMarkdownFence(aiSummary))
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
                        if context != nil {
                            ContextBubble(text: context ?? "")
                        }
                        ForEach(conversation) { entry in
                            MessageBubble(entry: entry, onBotMessageClick: onBotMessageClick)
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
                    TextField("Ask anything", text: $userQuery)
                        .textFieldStyle(.plain)
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
            if toolbarVisible {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newChat()
                    } label: {
                        Label("New Chat", systemImage: "plus.message")
                    }
                    #if !os(visionOS)
                    .glassEffect()
                    #endif
                    .help("New Chat")
                }
            }

        }
        .onAppear {
            textFieldFocused = true
        }
    }
}
