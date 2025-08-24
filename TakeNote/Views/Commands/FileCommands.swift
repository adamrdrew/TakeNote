//
//  FileCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/23/25.
//

import SwiftData
import SwiftUI
import os

struct FileCommands: Commands {
    @FocusedValue(TakeNoteVM.self) private var takeNoteVM: TakeNoteVM?
    @FocusedValue(SearchIndexService.self) private var search:
        SearchIndexService?
    @FocusedValue(\.modelContext) private var modelContext: ModelContext?

    let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "FileMenu"
    )

    @Query() var notes: [Note]
    
    var vmOrModelContextAreNil : Bool {
        takeNoteVM == nil || modelContext == nil
    }

    var body: some Commands {

        CommandGroup(after: .newItem) {
            /// Create a new note
            Button("New Note", systemImage: "note.text.badge.plus") {
                takeNoteVM?.addNote(modelContext!)
            }
            .disabled(
                takeNoteVM?.canAddNote == false || vmOrModelContextAreNil
            )
            .keyboardShortcut("N", modifiers: [.command])
            
            /// Create a new folder
            Button("New Folder", systemImage: "folder.badge.plus") {
                takeNoteVM?.addFolder(modelContext!)
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("F", modifiers: [.command])
            
            /// Create a new tag
            Button("New Tag", systemImage: "tag") {
                takeNoteVM?.addTag("New Tag", modelContext: modelContext!)
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("T", modifiers: [.command])
            
        }
    }
}
