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
    var sources: [SearchHit] = []
    var isComplete: Bool = false

    init(sender: Sender, text: String) {
        self.id = UUID()
        self.sender = sender
        self.text = text
    }
}

struct ChatWindow: View {
    @Environment(SearchIndexService.self) private var search

    @Query() var allNotes: [Note]

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotPhase: Double = 0


    // MARK: - Actions

    private func askQuestion() {
        let trimmed = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !responseIsGenerating else { return }

        responseIsGenerating = true

        let conversationEntry = ConversationEntry(sender: .human, text: trimmed)
        conversation.append(conversationEntry)

        // Prepare retrieval and freeze sources at ask-time
        if searchEnabled {
            self.searchResults = search.index.searchNatural(trimmed)
        }
        let capturedSources = searchResults

        // Clear the field & keep focus
        self.userQuery = ""
        self.textFieldFocused = true

        Task { await generateResponse(sources: capturedSources) }
    }

    private func makeConversationString() -> String {
        // Generate a log of the conversation and senders
        return conversation.map { entry in
            "\(entry.sender == .human ? "User" : "Assistant"): \(entry.text)"
        }.joined(separator: "\n")
    }

    private func stripMarkdown(_ text: String) -> String {
        var s = text
        // Remove images and links but keep link text
        s = s.replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[([^\]]*)\]\(.*?\)"#, with: "$1", options: .regularExpression)
        // Remove fenced code blocks (``` ... ```)
        s = s.replacingOccurrences(of: #"```[^`]*```"#, with: "", options: .regularExpression)
        // Remove inline code
        s = s.replacingOccurrences(of: #"`[^`]+`"#, with: "", options: .regularExpression)
        // Remove heading markers, bold, italic, strikethrough
        s = s.replacingOccurrences(of: #"#{1,6}\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[*_~]{1,3}"#, with: "", options: .regularExpression)
        // Remove checkbox markers
        s = s.replacingOccurrences(of: #"- \[[ x]\] "#, with: "- ", options: .regularExpression)
        // Collapse multiple blank lines
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makePrompt() -> String {
        var llmPrompt = ""
        if searchEnabled {
            llmPrompt += "TEXT FROM USER'S NOTES:\n\n"
            for (index, result) in searchResults.enumerated() {
                let cleaned = stripMarkdown(result.chunk)
                guard !cleaned.isEmpty else { continue }
                llmPrompt += "EXCERPT \(index + 1):\n\(cleaned)\n\n"
            }
        }
        if context != nil {
            llmPrompt += "CONTEXT:\n\(context ?? "")\n\n"
        }
        if useHistory && conversation.count > 1 {
            llmPrompt += "CHAT HISTORY:\n\(makeConversationString())\n\n"
        }
        llmPrompt += "QUESTION: \(conversation.last?.text ?? "")\n"
        return llmPrompt
    }

    private func noteTitle(for noteID: UUID) -> String {
        allNotes.first(where: { $0.uuid == noteID })?.title ?? "Note"
    }

    private func generateResponse(sources: [SearchHit]) async {
        guard SystemLanguageModel.default.availability == .available else {
            var unavailableEntry = ConversationEntry(sender: .bot, text: "Apple Intelligence is not available on this device.")
            unavailableEntry.isComplete = true
            conversation.append(unavailableEntry)
            responseIsGenerating = false
            return
        }

        let modelInstructions = instructions ?? MAGIC_CHAT_PROMPT

        // Append bot entry before streaming begins so SwiftUI renders the bubble immediately
        var botEntry = ConversationEntry(sender: .bot, text: "")
        botEntry.sources = sources
        conversation.append(botEntry)
        let botIndex = conversation.count - 1

        let assembledPrompt = makePrompt()
        #if DEBUG
        let logger = search.logger
        logger.debug("Assembled prompt for LLM:\n\(assembledPrompt)")
        #endif

        let session = LanguageModelSession(instructions: modelInstructions)
        let stream = session.streamResponse(to: assembledPrompt)

        do {
            for try await partial in stream {
                conversation[botIndex].text = partial.content
            }
            conversation[botIndex].text = unwrapMarkdownFence(conversation[botIndex].text)
            conversation[botIndex].isComplete = true
        } catch {
            conversation[botIndex].text = "Something went wrong. Sorry."
            conversation[botIndex].isComplete = true
        }

        responseIsGenerating = false
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
                            MessageBubble(entry: entry, onBotMessageClick: onBotMessageClick, notes: allNotes)
                                .id(entry.id)
                                .padding(.horizontal, 12)
                                .padding(.top, 2)
                        }

                        // Three-dot animated indicator while waiting for first streaming token
                        if let lastEntry = conversation.last, lastEntry.sender == .bot, lastEntry.text.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color.secondary.opacity(0.6))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(dotPhase > Double(i) * (1.0 / 3.0) ? 1.3 : 1.0)
                                        .animation(
                                            reduceMotion ? nil : .easeInOut(duration: 0.4).delay(Double(i) * 0.15),
                                            value: dotPhase
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onAppear {
                                guard !reduceMotion else { return }
                                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: true)) {
                                    dotPhase = 1.0
                                }
                            }
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
                .disabled(responseIsGenerating)
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
