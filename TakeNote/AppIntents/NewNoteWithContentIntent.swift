//
//  NewNoteWithContentIntent.swift
//  TakeNote
//
//  Created by Adam Drew on 9/19/25.
//

import AppIntents
import SwiftUI
import SwiftData

struct NewNoteWithContentIntent: AppIntent {
    
    @Dependency(key: "ModelContainer") // key required for Swift 6 runtime.
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM") // key required for Swift 6 runtime.
    private var takeNoteVM: TakeNoteVM
    
    @Parameter(title: "Note Content", description: "The content you want in the new note")
    var content: String
    @Parameter(title: "Note Title", description: "The title you want for the new note")
    var noteTitle: String
    
    static var title: LocalizedStringResource = "Create a new note with content"


    static var description = IntentDescription("Opens TakeNote and creates a new note in the Inbox with the specified content.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        takeNoteVM.selectedContainer = takeNoteVM.inboxFolder
        let note = takeNoteVM.addNote(modelContainer.mainContext)

        if let note {
            note.content = content
            note.title = noteTitle
            takeNoteVM.openNote = note
            takeNoteVM.selectedNotes = [note]
        } else {
            // If addNote failed to create a note, clear current selection to avoid stale state
            takeNoteVM.openNote = nil
            takeNoteVM.selectedNotes = []
        }

        return .result()
    }
    
}
