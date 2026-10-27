//
//  Link.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftData

// If persisted fields change, bump ckBootstrapVersionCurrent in TakeNoteApp.swift,
// run a DEBUG build to update the CloudKit development schema, then promote it.

@Model
final class NoteLink {
    @Relationship(inverse: \Note.outgoingLinks)
    var sourceNote: Note?
    @Relationship(inverse: \Note.incomingLinks)
    var destinationNote: Note?
    
    init(sourceNote: Note, destinationNote: Note) {
        self.sourceNote = sourceNote
        self.destinationNote = destinationNote
    }
}
