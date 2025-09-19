//
//  NewNoteIntent.swift
//  TakeNote
//
//  Created by Adam Drew on 9/19/25.
//

import AppIntents
import SwiftUI
import SwiftData

struct NewNoteIntent: AppIntent {
    
    @Dependency(key: "ModelContainer") // key required for Swift 6 runtime.
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM") // key required for Swift 6 runtime.
    private var takeNoteVM: TakeNoteVM
    
    static var title: LocalizedStringResource = "Create a new note"


    static var description = IntentDescription("Opens TakeNote and creates a new note in the Inbox.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        takeNoteVM.selectedContainer = takeNoteVM.inboxFolder
        let note = takeNoteVM.addNote(modelContainer.mainContext)
        takeNoteVM.openNote = note
        
        return .result()
    }
    
}
