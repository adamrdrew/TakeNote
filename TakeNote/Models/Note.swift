//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

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
class Note : Identifiable {
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var starred : Bool = false
    // This odd syntax makes the setter private to the instance
    // so we can act like this is a private property
    // but SwiftData can still set it
    private(set) var uuid : UUID = UUID()
    @Relationship(inverse: \NoteContainer.folderNotes) var folder : NoteContainer
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

}
