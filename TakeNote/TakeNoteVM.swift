//
//  TakeNoteVM.swift
//  TakeNote
//
//  Created by Adam Drew on 8/21/25.
//

import SwiftUI

@Observable
class TakeNoteVM {
    // The note currently open in the editor
    var openNote: Note?
    // The folder or tag the user is viewing
    var selectedContainer: NoteContainer?

}
