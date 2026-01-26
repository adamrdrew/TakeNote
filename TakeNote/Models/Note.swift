//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CryptoKit
import FoundationModels
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

extension UTType {
    static let noteID = UTType(exportedAs: "com.adamdrew.takenote.noteid")
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
    @Relationship var imageLinks: [NoteImageLink]? = []

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
        let model = SystemLanguageModel.default
        if isEmpty {
            return false
        }
        if !contentHasChanged() {
            return false
        }
        if aiSummaryIsGenerating {
            return false
        }
        if model.availability != .available {
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
        contentHash = generateContentHash()
        aiSummaryIsGenerating = true
        aiSummary = ""
        let instructions = """
            Write a single-line summary of the passage. State the core point directly. Do not mention the passage or the act of summarizing. No prefaces, labels, citations, or quotes. Preserve key entities and facts. Output exactly one sentence with no line breaks.
            """
        let session = LanguageModelSession(instructions: instructions)
        if session.isResponding { return }
        let prompt = content
        let response = try? await session.respond(to: prompt)
        aiSummary = response?.content ?? ""
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
