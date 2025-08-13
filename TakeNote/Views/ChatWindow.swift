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
        prompt += "Use the following source documents to answer the question:\n\n"
        for result in searchResults {
            prompt += "- \(result.chunk)\n"
        }
        prompt += "Conversation history:\n\n\(makeConversationString())\n\n"
        return prompt
    }

    private func generateResponse() async {
        let instructions =
        """
        You are a helpful note curation assistant. You will be provided a user question and some source documents that are related to the question. Use the sources to answer the user's question. You will also be provided the conversation history which you can also use to answer questions. Be brief, but accurate. Don't make reference to any world knowledge, answer the question only based on what you see in the provided source documents and chat history. Only craft your answers based on the source documents and chat history entries that seem relevant to the user's question. If a source document or conversation history reference isn't relevant to the user's question just disregard that source. Note that all documents are from the user's personal notes.
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
                            HStack {
                                MessageBubble(entry: .init(sender: .bot, text: "…"))
                                    .redacted(reason: .placeholder)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 2)
                        }

                        // Bottom spacer to anchor scroll
                        Color.clear.frame(height: 1).id("BOTTOM")
                    }
                    .padding(.vertical, 8)
                }
                .background(.background)
                .onChange(of: conversation.count) { _ , _ in
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

                if responseIsGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 4)
                } else {
                    Button {
                        askQuestion()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .imageScale(.medium)
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .help("Send (⌘↩)")
                    .disabled(userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .glassEffect()
                }
            }
            .padding(10)
            .background(.bar) // blends like a toolbar at the bottom
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

// MARK: - Message Bubble

private struct MessageBubble: View {
    let entry: ConversationEntry

    var isHuman: Bool { entry.sender == .human }

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 40) }
            bubble
                .frame(maxWidth: 520, alignment: isHuman ? .trailing : .leading)
            if !isHuman { Spacer(minLength: 40) }
        }
    }

    private var bubble: some View {
        Text(entry.text)
            .textSelection(.enabled)
            .font(.body)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(isHuman ? .white : .primary)
            .background(
                Group {
                    if isHuman {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                            .glassEffect(in: .rect(cornerRadius: 8.0))
                    } else {
                        // Subtle material-style look for received messages
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                            .glassEffect(in: .rect(cornerRadius: 8.0))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isHuman ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .transition(.move(edge: isHuman ? .trailing : .leading).combined(with: .opacity))
    }
}
