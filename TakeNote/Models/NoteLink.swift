//
//  Link.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftData
import SwiftUI

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
