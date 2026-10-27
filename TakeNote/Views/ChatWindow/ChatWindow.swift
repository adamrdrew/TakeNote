//
//  ChatWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import CoreSpotlight
import FoundationModels
import os
import SwiftData
import SwiftUI

enum Sender: Hashable, Sendable {
    case human
    case bot
}

struct ConversationEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let sender: Sender
    var text: String
    var sources: [SearchHit] = []
    var isComplete: Bool = false
    var toolCallStatus: ToolCallStatus? = nil

    init(sender: Sender, text: String) {
        self.id = UUID()
        self.sender = sender
        self.text = text
    }
}

// Title color cycle used for animated generation feedback on iOS.
#if os(iOS)
private let titleColors: [Color] = [.takeNotePink, .orange, .purple, .blue]
#endif

private struct ChatEmptyStatePlaceholder: View {
    let title: LocalizedStringResource
    let description: LocalizedStringResource

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(.secondary)
            Text(description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if os(iOS)
private struct ChatTitleBar: View {
    let responseIsGenerating: Bool
    let reduceMotion: Bool
    let titleColorPhase: Int
    let title: LocalizedStringResource
    let newChat: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(
                        responseIsGenerating && !reduceMotion
                            ? titleColors[titleColorPhase]
                            : Color.takeNotePink
                    )
                    .animation(.easeInOut(duration: 0.4), value: titleColorPhase)

                HStack {
                    Spacer()
                    Button {
                        newChat()
                    } label: {
                        Image(systemName: "plus.message")
                            .foregroundStyle(Color.takeNotePink)
                    }
                    .help("New Chat")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
        }
    }
}
#endif

struct ChatWindow: View {
    private static let logger = Logger(subsystem: "com.adamdrew.takenote", category: "ChatWindow")

    @Environment(SearchIndexService.self) private var search
    @Environment(\.modelContext) private var modelContext

    @State private var conversation: [ConversationEntry] = []
    @State private var userQuery: String = ""
    @State private var session: LanguageModelSession? = nil
    @State private var pendingSources: [SearchHit] = []
    @State private var responseIsGenerating: Bool = false
    @State private var responseTask: Task<Void, Never>?
    @State private var searchResultsTask: Task<Void, Never>?
    @State private var responseID: UUID?

    let context: String?
    let instructions: String?
    let searchEnabled: Bool
    let onBotMessageClick: ((String) -> Void)?
    let toolbarVisible: Bool
    let useHistory: Bool
    let windowTitleText: LocalizedStringResource
    let windowTitleDescription: LocalizedStringResource
    let chatBoxPlaceholder: LocalizedStringResource

    @FocusState private var textFieldFocused: Bool

    // MARK: - iOS-only state

    #if os(iOS)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleColorPhase: Int = 0
    #endif

    init(
        context: String? = nil,
        instructions: String? = nil,
        searchEnabled: Bool = true,
        onBotMessageClick: ((String) -> Void)? = nil,
        toolbarVisible: Bool = true,
        useHistory: Bool = true,
        windowTitleText: LocalizedStringResource = "Magic Chat",
        windowTitleDescription: LocalizedStringResource = "Chat with your notes using natural language and on-device, private AI.",
        chatBoxPlaceholder: LocalizedStringResource = "What do you want to know?"
    ) {
        self.context = context
        self.instructions = instructions
        self.searchEnabled = searchEnabled
        self.onBotMessageClick = onBotMessageClick
        self.toolbarVisible = toolbarVisible
        self.useHistory = useHistory
        self.windowTitleText = windowTitleText
        self.windowTitleDescription = windowTitleDescription
        self.chatBoxPlaceholder = chatBoxPlaceholder
    }

    // MARK: - Actions

    private func askQuestion() {
        let trimmed = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !responseIsGenerating else { return }

        responseIsGenerating = true

        conversation.append(ConversationEntry(sender: .human, text: trimmed))
        pendingSources = []

        // Clear the field & keep focus
        self.userQuery = ""
        self.textFieldFocused = true

        let requestID = UUID()
        responseID = requestID
        responseTask = Task { await generateResponse(userPrompt: trimmed, requestID: requestID) }
    }

    private func generateResponse(userPrompt: String, requestID: UUID) async {
        defer {
            if responseID == requestID {
                searchResultsTask?.cancel()
                searchResultsTask = nil
                responseIsGenerating = false
                textFieldFocused = true
            }
        }

        guard activeLanguageModel.availability == .available else {
            var unavailableEntry = ConversationEntry(sender: .bot, text: "Apple Intelligence is not available on this device.")
            unavailableEntry.isComplete = true
            conversation.append(unavailableEntry)
            return
        }
        if searchEnabled {
            await search.waitForPendingIndexing()
            guard responseID == requestID, !Task.isCancelled else { return }
        }

        // Each turn gets its own tools and tasks. Visible history survives changes
        // in write-tool access without retaining hidden tool output indefinitely.
        let history = useHistory ? Array(conversation.dropLast()) : []
        let prompt = ChatRequest.prompt(userPrompt, context: context, history: history)

        // Append bot entry before streaming begins so SwiftUI renders the bubble immediately
        conversation.append(ConversationEntry(sender: .bot, text: ""))
        let botIndex = conversation.count - 1
        let botID = conversation[botIndex].id
        session = buildSession(
            allowsNoteCreation: searchEnabled && ChatRequest.allowsNoteCreation(userPrompt),
            requestID: requestID,
            botID: botID
        )

        #if DEBUG
        Self.logger.debug(
            "Sending LLM prompt. length=\(prompt.count), hasContext=\(context != nil)"
        )
        #endif

        do {
            guard let session else {
                if conversation.indices.contains(botIndex) {
                    conversation[botIndex].text = "Something went wrong. Sorry."
                    conversation[botIndex].isComplete = true
                }
                return
            }
            let stream = session.streamResponse(
                to: TakeNoteLanguageModels.prompt(prompt),
                options: chatGenerationOptions,
                contextOptions: chatContextOptions
            )
            for try await partial in stream {
                try Task.checkCancellation()
                guard responseID == requestID, conversation.indices.contains(botIndex) else { return }
                let content = partial.content
                if content != "null" {
                    conversation[botIndex].text = content
                }
            }
            try Task.checkCancellation()
            guard responseID == requestID, conversation.indices.contains(botIndex) else { return }
            conversation[botIndex].text = unwrapMarkdownFence(conversation[botIndex].text)
            conversation[botIndex].sources = pendingSources
            conversation[botIndex].isComplete = true
        } catch let error as LanguageModelError where isContextOverflow(error) {
            // Compact the conversation and retry instead of losing context
            guard responseID == requestID, !Task.isCancelled else { return }
            await compactAndRetry(userPrompt: userPrompt, botIndex: botIndex, requestID: requestID)
        } catch is CancellationError {
            if responseID == requestID, conversation.indices.contains(botIndex) {
                conversation[botIndex].isComplete = true
            }
        } catch {
            #if DEBUG
            Self.logger.error("generateResponse error: \(error)")
            #endif
            if responseID == requestID, conversation.indices.contains(botIndex) {
                conversation[botIndex].text = "Something went wrong. Sorry."
                conversation[botIndex].isComplete = true
            }
        }
    }

    private var activeLanguageModel: SystemLanguageModel {
        searchEnabled ? TakeNoteLanguageModels.chat : TakeNoteLanguageModels.contentTransformationFallback
    }

    private var chatGenerationOptions: GenerationOptions {
        GenerationOptions(
            samplingMode: .greedy,
            temperature: searchEnabled ? 0.2 : 0.0,
            toolCallingMode: searchEnabled ? .allowed : .disallowed
        )
    }

    private var chatContextOptions: ContextOptions {
        ContextOptions()
    }

    private func buildSession(
        conversationSummary: String? = nil,
        allowsNoteCreation: Bool = false,
        requestID: UUID,
        botID: UUID
    ) -> LanguageModelSession {
        let now = Date.now.formatted(date: .complete, time: .shortened)
        let baseInstructions = instructions ?? MAGIC_CHAT_PROMPT
        var modelInstructions = "\(baseInstructions)\n\nCurrent date and time: \(now)"
        if let conversationSummary {
            modelInstructions += "\n\nSummary of earlier conversation:\n\(conversationSummary)"
        }

        let newSession: LanguageModelSession
        #if targetEnvironment(simulator) && arch(x86_64)
        // The Intel simulator SDK omits SpotlightSearchTool. Model availability
        // is checked before generation, so unsupported hosts retain normal notes.
        newSession = LanguageModelSession(
            model: activeLanguageModel,
            instructions: TakeNoteLanguageModels.instructions(modelInstructions)
        )
        #else
        if searchEnabled {
            let searchTool = makeSpotlightSearchTool()
            observeSearchResults(from: searchTool, requestID: requestID, botID: botID)
            var tools: [any Tool] = [searchTool]
            if allowsNoteCreation {
                let createTool = CreateNoteTool(
                    onStatusChange: { [self] status in
                        guard responseID == requestID, !Task.isCancelled,
                              let idx = conversation.firstIndex(where: { $0.id == botID }) else { return }
                        conversation[idx].toolCallStatus = status
                    },
                    onCreate: { [self] title, content in
                        guard responseID == requestID, !Task.isCancelled else { return nil }
                        return createNoteInInbox(title: title, content: content)
                    }
                )
                tools.append(createTool)
            }
            newSession = LanguageModelSession(
                model: activeLanguageModel,
                tools: tools,
                instructions: TakeNoteLanguageModels.instructions(modelInstructions)
            )
        } else {
            newSession = LanguageModelSession(
                model: activeLanguageModel,
                instructions: TakeNoteLanguageModels.instructions(modelInstructions)
            )
        }
        #endif
        newSession.prewarm(promptPrefix: TakeNoteLanguageModels.prompt(context ?? ""))
        return newSession
    }

    #if !(targetEnvironment(simulator) && arch(x86_64))
    private func makeSpotlightSearchTool() -> SpotlightSearchTool {
        var source = CoreSpotlightSource(
            searchableIndexDelegate: search.searchableIndexDelegate,
            fetchAttributes: [
                .title,
                .displayName,
                .subject,
                .textContent,
                .contentDescription,
                .keywords,
                .identifier,
                .domainIdentifier,
                .contentCreationDate,
                .contentModificationDate,
                .containerTitle
            ]
        )
        source.maximumResultCount = 12

        let profile = SpotlightSearchTool.GuidanceProfile(
            textMatch: true,
            similarityMatch: true,
            numericMatch: false,
            dates: true,
            people: false,
            contentType: false,
            attributes: [
                .title,
                .displayName,
                .subject,
                .textContent,
                .contentDescription,
                .keywords,
                .containerTitle,
                .contentCreationDate,
                .contentModificationDate,
                .metadataModificationDate
            ]
        )
        let guide = SpotlightSearchTool.Guide(
            level: .dynamic(profile),
            format: .compact
        )
        let configuration = SpotlightSearchTool.Configuration(
            sources: [.coreSpotlight(source)],
            guide: guide
        )
        return SpotlightSearchTool(configuration: configuration)
    }

    private func observeSearchResults(from tool: SpotlightSearchTool, requestID: UUID, botID: UUID) {
        searchResultsTask?.cancel()
        searchResultsTask = Task {
            for await reply in tool.searchResults {
                guard !Task.isCancelled, responseID == requestID else { return }
                handleSearchReply(reply, botID: botID)
            }
        }
    }

    private func handleSearchReply(_ reply: SpotlightSearchTool.SearchReply, botID: UUID) {
        let hits = searchHits(from: reply.content)
        mergePendingSources(hits)

        guard let idx = conversation.firstIndex(where: { $0.id == botID }) else { return }
        conversation[idx].sources = pendingSources

        if pendingSources.isEmpty {
            conversation[idx].toolCallStatus = reply.status == .complete ? .noResultsFound : .searchingNotes
        } else {
            conversation[idx].toolCallStatus = .foundResults(pendingSources.count)
        }
    }

    private func searchHits(from content: SpotlightSearchTool.SearchReply.Content) -> [SearchHit] {
        switch content {
        case .items(let items):
            items.compactMap(searchHit(from:))
        case .scoredItems(let scoredItems):
            scoredItems.compactMap { searchHit(from: $0.item) }
        case .groupedItems(let groupedItems):
            groupedItems.values.flatMap { items in
                items.compactMap(searchHit(from:))
            }
        case .count, .table, .statistic, .text:
            []
        @unknown default:
            []
        }
    }

    private func searchHit(from result: SearchableItem) -> SearchHit? {
        let item = result.item
        guard item.domainIdentifier == NoteSpotlightIndex.domainIdentifier else {
            return nil
        }
        guard let noteID = UUID(uuidString: item.uniqueIdentifier) else {
            return nil
        }

        let attributes = item.attributeSet
        let chunk = attributes.textContent
            ?? attributes.contentDescription
            ?? attributes.title
            ?? ""

        return SearchHit(
            id: item.uniqueIdentifier,
            noteID: noteID,
            noteTitle: attributes.title ?? attributes.displayName,
            chunk: chunk
        )
    }

    private func mergePendingSources(_ hits: [SearchHit]) {
        for hit in hits where !pendingSources.contains(where: { $0.id == hit.id }) {
            pendingSources.append(hit)
        }
    }
    #endif

    /// Summarize the conversation so far, rebuild the session with the summary
    /// baked into instructions, and retry the user's last message.
    private func compactAndRetry(userPrompt: String, botIndex: Int, requestID: UUID) async {
        guard responseID == requestID, conversation.indices.contains(botIndex) else { return }
        searchResultsTask?.cancel()

        guard TakeNoteLanguageModels.contentTagging.isAvailable else {
            conversation[botIndex].text = "The conversation grew too long. Please start a new chat."
            conversation[botIndex].isComplete = true
            return
        }

        // Build a text summary of the conversation (exclude the current empty bot entry)
        let historyText = conversation.prefix(botIndex).map { entry in
            let role = entry.sender == .human ? "User" : "Assistant"
            return "\(role): \(entry.text)"
        }.joined(separator: "\n")

        let summaryPrompt = """
            Summarize this conversation for continuity.
            Capture key topics, facts discussed, user preferences, and any decisions made.
            Keep it under 150 words.

            \(String(historyText.suffix(6000)))
            """
        let summarySession = LanguageModelSession(
            profile: TakeNoteLanguageModels.profile(
                instructions: "Return only the compact conversation summary.",
                model: TakeNoteLanguageModels.contentTagging,
                maximumResponseTokens: 180
            )
        )

        let summary: String
        do {
            let response = try await summarySession.respond(to: TakeNoteLanguageModels.prompt(summaryPrompt))
            summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch is CancellationError {
            if responseID == requestID, conversation.indices.contains(botIndex) {
                conversation[botIndex].isComplete = true
            }
            return
        } catch {
            // If summarization itself fails, fall back to a hard reset
            guard responseID == requestID else { return }
            if conversation.indices.contains(botIndex) {
                conversation[botIndex].text = "The conversation grew too long. Starting a fresh session — please ask your question again."
                conversation[botIndex].isComplete = true
            }
            session = nil
            return
        }

        guard responseID == requestID, !Task.isCancelled, conversation.indices.contains(botIndex) else { return }

        // Rebuild session with summary context and retry
        let allowsNoteCreation = searchEnabled && ChatRequest.allowsNoteCreation(userPrompt)
        session = buildSession(
            conversationSummary: summary,
            allowsNoteCreation: allowsNoteCreation,
            requestID: requestID,
            botID: conversation[botIndex].id
        )

        var prompt = userPrompt
        if let context {
            prompt = "CONTEXT:\n\(context)\n\nQUESTION: \(prompt)"
        }

        do {
            guard let session else {
                if conversation.indices.contains(botIndex) {
                    conversation[botIndex].text = "Something went wrong after compacting the conversation. Sorry."
                    conversation[botIndex].isComplete = true
                }
                return
            }
            let stream = session.streamResponse(
                to: TakeNoteLanguageModels.prompt(prompt),
                options: chatGenerationOptions,
                contextOptions: chatContextOptions
            )
            for try await partial in stream {
                try Task.checkCancellation()
                guard responseID == requestID, conversation.indices.contains(botIndex) else { return }
                let content = partial.content
                if content != "null" {
                    conversation[botIndex].text = content
                }
            }
            try Task.checkCancellation()
            guard responseID == requestID, conversation.indices.contains(botIndex) else { return }
            conversation[botIndex].text = unwrapMarkdownFence(conversation[botIndex].text)
            conversation[botIndex].sources = pendingSources
            conversation[botIndex].isComplete = true
        } catch is CancellationError {
            if responseID == requestID, conversation.indices.contains(botIndex) {
                conversation[botIndex].isComplete = true
            }
        } catch {
            guard responseID == requestID else { return }
            if conversation.indices.contains(botIndex) {
                conversation[botIndex].text = "Something went wrong after compacting the conversation. Sorry."
                conversation[botIndex].isComplete = true
            }
            session = nil
        }
    }

    private func isContextOverflow(_ error: LanguageModelError) -> Bool {
        if case .contextSizeExceeded = error { return true }
        return false
    }

    private func createNoteInInbox(title: String, content: String) -> UUID? {
        let inboxPredicate = #Predicate<NoteContainer> { $0.isInbox == true }
        let descriptor = FetchDescriptor(predicate: inboxPredicate)
        let inbox: NoteContainer?
        do {
            inbox = try modelContext.fetch(descriptor).first
        } catch {
            Self.logger.error("CreateNote failed while fetching Inbox: \(error.localizedDescription)")
            return nil
        }
        guard let inbox else {
            Self.logger.error("CreateNote failed: could not find Inbox folder")
            return nil
        }
        let note = Note(folder: inbox)
        modelContext.insert(note)
        note.setTitle(title)
        note.setContent(content)
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("CreateNote failed: \(error.localizedDescription)")
            modelContext.delete(note)
            return nil
        }
        search.reindex(note: note)
        Self.logger.debug("CreateNote succeeded: \(note.uuid)")
        return note.uuid
    }

    private func newChat() {
        responseTask?.cancel()
        responseTask = nil
        searchResultsTask?.cancel()
        searchResultsTask = nil
        conversation.removeAll()
        session = nil
        responseID = nil
        pendingSources = []
        userQuery = ""
        responseIsGenerating = false
        textFieldFocused = true
    }

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {

            // iOS title bar (replaces toolbar New Chat button on iOS)
            #if os(iOS)
            if toolbarVisible {
                ChatTitleBar(
                    responseIsGenerating: responseIsGenerating,
                    reduceMotion: reduceMotion,
                    titleColorPhase: titleColorPhase,
                    title: windowTitleText,
                    newChat: newChat
                )
            }
            #endif

            // Messages
            ScrollViewReader { proxy in
                ScrollView {

                    LazyVStack(spacing: 8) {
                        if context != nil {
                            ContextBubble(text: context ?? "")
                        }
                        ForEach(conversation) { entry in
                            MessageBubble(
                                entry: entry,
                                onBotMessageClick: onBotMessageClick
                            )
                                .id(entry.id)
                                .padding(.horizontal, 12)
                                .padding(.top, 2)
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
                // Empty-state placeholder layered inside the scroll area (macOS and iOS)
                .overlay {
                    if conversation.isEmpty {
                        ChatEmptyStatePlaceholder(
                            title: windowTitleText,
                            description: windowTitleDescription
                        )
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                // Rounded, iMessage-like input
                HStack(spacing: 8) {
                    TextField(text: $userQuery, prompt: Text(chatBoxPlaceholder)) {
                        EmptyView()
                    }
                        .textFieldStyle(.plain)
                        .focused($textFieldFocused)
                        .onSubmit(askQuestion)

                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .disabled(responseIsGenerating)
            }
            .padding(10)
            .background(.bar)  // blends like a toolbar at the bottom
        }
        .toolbar {
            // On iOS the New Chat button lives in the TitleBar; on macOS and visionOS use the toolbar.
            #if os(macOS)
            if toolbarVisible {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newChat()
                    } label: {
                        Label("New Chat", systemImage: "plus.message")
                    }
                    .glassEffect()
                    .help("New Chat")
                }
            }
            #endif
            #if os(visionOS)
            if toolbarVisible {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newChat()
                    } label: {
                        Label("New Chat", systemImage: "plus.message")
                    }
                    .help("New Chat")
                }
            }
            #endif
        }
        .onAppear {
            textFieldFocused = true
        }
        .onDisappear {
            responseID = nil
            responseTask?.cancel()
            responseTask = nil
            searchResultsTask?.cancel()
            searchResultsTask = nil
            session = nil
            responseIsGenerating = false
        }
        #if os(iOS)
        .onOpenURL { _ in
            dismiss()
        }
        .task(id: responseIsGenerating) {
            guard responseIsGenerating, !reduceMotion else {
                titleColorPhase = 0
                return
            }
            while responseIsGenerating && !reduceMotion {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
                guard responseIsGenerating && !reduceMotion else {
                    return
                }
                titleColorPhase = (titleColorPhase + 1) % titleColors.count
            }
        }
        #endif
    }
}
