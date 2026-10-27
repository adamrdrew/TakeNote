//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CoreTransferable
import CryptoKit
import Foundation
import FoundationModels
import os
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

extension UTType {
    nonisolated static let noteID = UTType(exportedAs: "com.adamdrew.takenote.noteid")
}

enum TakeNoteLanguageModels {
    nonisolated static let chat = SystemLanguageModel(useCase: .general)
    nonisolated static let contentTagging = SystemLanguageModel(useCase: .contentTagging)
    nonisolated static let contentTransformation = SystemLanguageModel(
        useCase: .general,
        guardrails: .permissiveContentTransformations
    )
    nonisolated static let contentTransformationFallback = SystemLanguageModel(useCase: .general)

    nonisolated static func profile(
        instructions: String,
        model: SystemLanguageModel = chat,
        toolCallingMode: GenerationOptions.ToolCallingMode = .disallowed,
        samplingMode: GenerationOptions.SamplingMode = .greedy,
        temperature: Double? = 0.0,
        maximumResponseTokens: Int? = nil,
        reasoningLevel: ContextOptions.ReasoningLevel? = nil
    ) -> some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile {
            Instructions {
                instructions
            }
        }
        .model(model)
        .samplingMode(samplingMode)
        .temperature(temperature)
        .maximumResponseTokens(maximumResponseTokens)
        .reasoningLevel(reasoningLevel)
        .toolCallingMode(toolCallingMode)
    }

    nonisolated static func instructions(_ text: String) -> Instructions {
        Instructions {
            text
        }
    }

    nonisolated static func prompt(_ text: String) -> Prompt {
        Prompt {
            text
        }
    }
}

// If persisted fields change, bump ckBootstrapVersionCurrent in TakeNoteApp.swift,
// run a DEBUG build to update the CloudKit development schema, then promote it.

struct NoteIDWrapper: Hashable, Codable, Transferable {
    let id: PersistentIdentifier

    init(id: PersistentIdentifier) {
        self.id = id
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .noteID) { wrapper in
            try JSONEncoder().encode(wrapper.id)
        } importing: { data in
            let id = try JSONDecoder().decode(
                PersistentIdentifier.self,
                from: data
            )
            return NoteIDWrapper(id: id)
        }
    }
}

@Model
final class Note: Identifiable {
    var defaultTitle: String = "New Note"
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var updatedDate: Date = Date()
    var starred: Bool = false
    var aiSummary: String = ""
    var contentHash: String = ""
    // Editor typing updates timestamps without reloading widgets on every keystroke.
    var editorContent: String {
        get { content }
        set {
            content = newValue
            updatedDate = Date()
        }
    }
    @Transient
    var aiSummaryIsGenerating: Bool = false
    var isEmpty: Bool { return content.isEmpty }
    private static let logger = Logger(subsystem: "com.adamdrew.takenote", category: "NoteSummary")
    // This odd syntax makes the setter private to the instance
    // so we can act like this is a private property
    // but SwiftData can still set it
    private(set) var uuid: UUID = UUID()
    @Relationship(deleteRule: .noAction, inverse: \NoteContainer.folderNotes)
    var folder: NoteContainer?
    @Relationship(deleteRule: .nullify, inverse: \NoteContainer.tagNotes)
    var tag: NoteContainer?
    @Relationship(deleteRule: .nullify, inverse: \NoteContainer.starredNotes)
    var starredFolder: NoteContainer?

    // Keep these as relationships but DO NOT specify inverses here
    // (we'll specify inverses on NoteLink to avoid macro circularity).
    @Relationship var outgoingLinks: [NoteLink]? = []
    @Relationship var incomingLinks: [NoteLink]? = []

    init(folder: NoteContainer) {
        self.title = self.defaultTitle
        self.content = ""
        self.createdDate = Date()
        self.updatedDate = Date()

        self.folder = folder
        self.starred = false
        self.uuid = UUID()
        
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.updatedDate = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setContent(_ newContent: String) {
        self.content = newContent
        self.updatedDate = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setFolder(_ folder: NoteContainer) {
        self.folder = folder
        self.updatedDate = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setTag(_ tag: NoteContainer) {
        self.tag = tag
        self.updatedDate = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func getURL() -> String {
        return "takenote://note/\(uuid.uuidString)"
    }

    func getMarkdownLink() -> String {
        return "[\(title)](\(getURL()))"
    }

    func generateContentHash() -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func contentHasChanged() -> Bool {
        let newHash = generateContentHash()
        return newHash != contentHash
    }

    func canGenerateAISummary() -> Bool {
        if isEmpty {
            return false
        }
        if !contentHasChanged() {
            return false
        }
        if aiSummaryIsGenerating {
            return false
        }
        if TakeNoteLanguageModels.contentTagging.availability != .available
            && TakeNoteLanguageModels.contentTransformationFallback.availability != .available
        {
            return false
        }
        return true
    }

    func generateSummary() async {
        if !canGenerateAISummary() {
            return
        }
        defer {
            aiSummaryIsGenerating = false
        }
        let newContentHash = generateContentHash()
        aiSummaryIsGenerating = true
        let instructions = """
            Write one plain-language summary sentence for a note.
            State the core point directly.
            Preserve important names, dates, amounts, decisions, and tasks.
            Do not mention the note, passage, or act of summarizing.
            Do not add labels, bullets, citations, quotes, markdown, or line breaks.
            """
        let model = TakeNoteLanguageModels.contentTagging.availability == .available
            ? TakeNoteLanguageModels.contentTagging
            : TakeNoteLanguageModels.contentTransformationFallback
        let session = LanguageModelSession(
            model: model,
            instructions: TakeNoteLanguageModels.instructions(instructions)
        )
        let prompt = TakeNoteLanguageModels.prompt(content)
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(samplingMode: .greedy, temperature: 0.0, maximumResponseTokens: 48)
            )
            guard !Task.isCancelled else { return }
            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else {
                Self.logger.warning("AI summary generation returned an empty response.")
                return
            }
            aiSummary = summary
            contentHash = newContentHash
        } catch is CancellationError {
            return
        } catch {
            Self.logger.warning("AI summary generation failed: \(error.localizedDescription)")
        }
    }

    func setTitle() {
        if title != defaultTitle {
            return
        }
        if content.isEmpty {
            return
        }
        let lines = content.components(separatedBy: "\n")

        if let firstLine = lines.first, !firstLine.isEmpty {
            do {
                let attributed = try AttributedString(markdown: firstLine)
                let plain = String(attributed.characters)
                setTitle(plain)
            } catch {
                setTitle(firstLine)
            }
        }
        return
    }

}
