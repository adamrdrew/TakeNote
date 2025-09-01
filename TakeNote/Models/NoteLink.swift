//
//  Link.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftData
import SwiftUI

// Hey!
// Hey you!
// If you change model schema remember to bump ckBootstrapVersionCurrent
// in TakeNoteApp.swift
//
// And don't forget to promote to prod!!!

@Model
class NoteLink {
    @Relationship(inverse: \Note.outgoingLinks)
    var sourceNote: Note?
    @Relationship(inverse: \Note.incomingLinks)
    var destinationNote: Note?
    
    init(sourceNote: Note, destinationNote: Note) {
        self.sourceNote = sourceNote
        self.destinationNote = destinationNote
    }
}
