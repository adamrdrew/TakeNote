//
//  NewNoteWithContentIntent.swift
//  TakeNote
//
//  Created by Adam Drew on 9/19/25.
//

import AppIntents
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
    
    static let title: LocalizedStringResource = "Create a new note with content"


    static let description = IntentDescription("Opens TakeNote and creates a new note in the Inbox with the specified content.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let inboxFolder = takeNoteVM.inboxFolder else {
            throw NoteIntentError.noteCreationFailed
        }

        let modelContext = modelContainer.mainContext
        let note = Note(folder: inboxFolder)
        note.setContent(content)
        note.setTitle(noteTitle)
        modelContext.insert(note)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(note)
            takeNoteVM.openNote = nil
            takeNoteVM.selectedNotes = []
            throw NoteIntentError.noteSaveFailed
        }

        takeNoteVM.selectedContainer = inboxFolder
        takeNoteVM.openNote = note
        takeNoteVM.selectedNotes = [note]

        return .result()
    }
    
}
