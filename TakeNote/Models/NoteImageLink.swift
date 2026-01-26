//
//  NoteImageLink.swift
//  TakeNote
//
//  Created by Adam Drew on 9/9/25.
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
class NoteImageLink {
    @Relationship(inverse: \Note.imageLinks)
    var sourceNote: Note?
    @Relationship(inverse: \NoteImage.noteLinks)
    var image: NoteImage?

    init(sourceNote: Note, image: NoteImage) {
        self.sourceNote = sourceNote
        self.image = image
    }
}
