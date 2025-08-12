//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import FoundationModels
import CryptoKit


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
class Note : Identifiable {
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var starred : Bool = false
    var aiSummary : String = ""
    var contentHash : String = ""
    var aiSummaryIsGenerating : Bool = false
    // This odd syntax makes the setter private to the instance
    // so we can act like this is a private property
    // but SwiftData can still set it
    private(set) var uuid : UUID = UUID()
    @Relationship(deleteRule: .noAction, inverse: \NoteContainer.folderNotes) var folder : NoteContainer
    @Relationship(deleteRule: .nullify, inverse: \NoteContainer.tagNotes) var tag : NoteContainer?
    
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
    
    func generateSummary() async {
        if content == "" {
            return
        }
        let newHash = generateContentHash()
        if newHash == contentHash {
            return
        }
        contentHash = newHash
        let model = SystemLanguageModel.default
        if model.availability != .available {
            return
        }
        aiSummaryIsGenerating  = true
        aiSummary = ""
        let instructions =
            "Generate a terse, and consice, one line summary of the provided text. Do not mention the source text at all, just provide the summary. Do not say things like 'the provided text says' or 'according to the provided text' or any other reference to the text itself. Just say whats in the text."
        let session = LanguageModelSession(instructions: instructions)
        if session.isResponding { return }
        let prompt = content
        let response = try? await session.respond(to: prompt)
        aiSummary = response?.content ?? ""
        aiSummaryIsGenerating  = false
    }

}
