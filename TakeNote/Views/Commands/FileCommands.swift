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

    var body: some Commands {

        CommandGroup(after: .newItem) {
            Button("New Note", systemImage: "note.text.badge.plus") {
                takeNoteVM?.addNote(modelContext!)
            }
            .disabled(
                takeNoteVM?.canAddNote == false || takeNoteVM == nil
                    || modelContext == nil
            )
            .keyboardShortcut("N", modifiers: [.command])
            Button("Rebuild Search Index", systemImage: "arrow.3.trianglepath")
            {
                if notes.isEmpty {
                    logger.debug("No notes to reindex.")
                    return
                }
                search?.dropAll()
                search?.reindexAll(notes)
                logger.debug("Rebuilt search index")
            }
            .disabled(search?.isIndexing == true || search == nil)
            .keyboardShortcut("R", modifiers: [.command, .option, .shift])
        }
    }
}
