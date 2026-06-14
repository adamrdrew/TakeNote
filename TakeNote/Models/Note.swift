//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CryptoKit
import FoundationModels
import os
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

extension UTType {
    static let noteID = UTType(exportedAs: "com.adamdrew.takenote.noteid")
}

enum TakeNoteLanguageModels {
    static let chat = SystemLanguageModel(useCase: .general)
    static let contentTagging = SystemLanguageModel(useCase: .contentTagging)
    static let contentTransformation = SystemLanguageModel(
        useCase: .general,
        guardrails: .permissiveContentTransformations
    )
    static let contentTransformationFallback = SystemLanguageModel(useCase: .general)

    static func profile(
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

    static func instructions(_ text: String) -> Instructions {
        Instructions {
            text
        }
    }

    static func prompt(_ text: String) -> Prompt {
        Prompt {
            text
        }
    }
}

// Hey!
// Hey you!
// If you change model schema remember to bump ckBootstrapVersionCurrent
// in TakeNoteApp.swift
//
// And don't forget to promote to prod!!!

struct NoteIDWrapper: Hashable, Codable, Transferable {
    let id: PersistentIdentifier
    private let snapshot: Data  // eager bytes to avoid work-at-quit

    init(id: PersistentIdentifier) {
        self.id = id
        self.snapshot = (try? JSONEncoder().encode(id)) ?? Data()
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .noteID) { wrapper in
            // Export: no SwiftData touched during app termination
            wrapper.snapshot
        } importing: { data in
            // Import: decode when pasting (normal app runtime)
            let id = try JSONDecoder().decode(
                PersistentIdentifier.self,
                from: data
            )
            return NoteIDWrapper(id: id)
        }
    }
}

@Model
class Note: Identifiable {
    var defaultTitle: String = "New Note"
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var updatedDate: Date = Date()
    var starred: Bool = false
    var aiSummary: String = ""
    var contentHash: String = ""
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
        let digest = Insecure.MD5.hash(data: content.data(using: .utf8)!)
        return digest.map { String(format: "%02hhx", $0) }.joined()
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
            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else {
                Self.logger.warning("AI summary generation returned an empty response.")
                return
            }
            aiSummary = summary
            contentHash = newContentHash
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
            if let attributed = try? AttributedString(markdown: firstLine) {
                let plain = String(attributed.characters)
                setTitle(plain)
            }
        }
        return
    }

}
