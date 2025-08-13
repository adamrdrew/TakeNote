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

extension UTType {
    static let noteID = UTType(exportedAs: "com.takenote.noteid")
}

struct NoteIDWrapper: Codable, Transferable, Hashable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .noteID)
    }
}

@Model
class Note: Identifiable {
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var starred: Bool = false
    var aiSummary: String = ""
    var contentHash: String = ""
    var aiSummaryIsGenerating: Bool = false
    var isEmpty: Bool { return content.isEmpty }
    // This odd syntax makes the setter private to the instance
    // so we can act like this is a private property
    // but SwiftData can still set it
    private(set) var uuid: UUID = UUID()
    @Relationship(deleteRule: .noAction, inverse: \NoteContainer.folderNotes)
    var folder: NoteContainer
    @Relationship(deleteRule: .nullify, inverse: \NoteContainer.tagNotes)
    var tag: NoteContainer?

    init(folder: NoteContainer) {
        self.title = "New Note"
        self.content = ""
        self.createdDate = Date()
        self.folder = folder
        self.starred = false
        self.uuid = UUID()
    }

    public func getURL() -> String {
        return "takenote://note/\(uuid.uuidString)"
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
        aiSummaryIsGenerating = false
    }

}
