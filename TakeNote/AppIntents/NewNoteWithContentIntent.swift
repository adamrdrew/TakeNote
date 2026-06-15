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
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService
    
    @Parameter(title: "Note Content", description: "The content you want in the new note")
    var content: String
    @Parameter(title: "Note Title", description: "The title you want for the new note")
    var noteTitle: String
    @Parameter(title: "Folder", description: "The folder for the new note")
    var folder: NoteFolderEntity?
    
    static let title: LocalizedStringResource = "Create a new note with content"


    static let description = IntentDescription("Opens TakeNote and creates a new note in the Inbox with the specified content.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let modelContext = modelContainer.mainContext
        let destinationFolder: NoteContainer
        if let folder {
            destinationFolder = try TakeNoteIntentStore.folder(for: folder, in: modelContext)
        } else {
            destinationFolder = try TakeNoteIntentStore.inbox(in: modelContext)
        }

        let note = Note(folder: destinationFolder)
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

        takeNoteVM.selectedContainer = destinationFolder
        takeNoteVM.openNote = note
        takeNoteVM.selectedNotes = [note]
        search.reindex(note: note)

        return .result(value: NoteSearchEntity(note: note))
    }
    
}
