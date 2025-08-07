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

struct NoteIDWrapper: Codable, Transferable {
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
    @Relationship(inverse: \Folder.notes) var folder : Folder
    
    init() {
        self.title = "New Note"
        self.content = ""
        self.createdDate = Date()
    @Relationship(inverse: \Folder.notes) var folder : Folder?
    
    init(folder: Folder? = nil) {
        self.title = "New Note"
        self.content = ""
        self.createdDate = Date()
        self.folder = folder
    }
}
