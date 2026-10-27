//
//  NewNoteIntent.swift
//  TakeNote
//
//  Created by Adam Drew on 9/19/25.
//

import AppIntents
import SwiftData

enum NoteIntentError: LocalizedError, Sendable {
    case noteCreationFailed
    case noteSaveFailed

    var errorDescription: String? {
        switch self {
        case .noteCreationFailed:
            return String(
                localized: "TakeNote could not create a new note.",
                comment: "Error shown when the Create Note app intent could not create a note."
            )
        case .noteSaveFailed:
            return String(
                localized: "TakeNote could not save the new note.",
                comment: "Error shown when the Create Note app intent created a note but could not save its content."
            )
        }
    }
}

struct NewNoteIntent: AppIntent {
    
    @Dependency(key: "ModelContainer") // key required for Swift 6 runtime.
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM") // key required for Swift 6 runtime.
    private var takeNoteVM: TakeNoteVM
    
    static let title: LocalizedStringResource = "Create a new note"


    static let description = IntentDescription("Opens TakeNote and creates a new note in the Inbox.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let inbox = try Self.inbox(in: context)
        takeNoteVM.inboxFolder = inbox
        takeNoteVM.selectedContainer = inbox
        let note = takeNoteVM.addNote(modelContainer.mainContext)

        if let note {
            takeNoteVM.openNote = note
            takeNoteVM.selectedNotes = [note]
        } else {
            takeNoteVM.openNote = nil
            takeNoteVM.selectedNotes = []
            throw NoteIntentError.noteCreationFailed
        }

        return .result()
    }
    
    @MainActor
    static func inbox(in context: ModelContext) throws -> NoteContainer {
        let descriptor = FetchDescriptor<NoteContainer>(predicate: #Predicate { $0.isInbox })
        if let inbox = try context.fetch(descriptor).first {
            return inbox
        }
        let inbox = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: true,
            isStarred: false,
            name: TakeNoteVM.inboxFolderName,
            symbol: "tray",
            isTag: false
        )
        context.insert(inbox)
        try context.save()
        return inbox
    }
}
