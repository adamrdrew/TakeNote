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
    @FocusedValue(\.showDeleteEverything) private var showDeleteEverything : (() -> Void)?

    let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "FileMenu"
    )

    @Query() var notes: [Note]

    var vmOrModelContextAreNil: Bool {
        takeNoteVM == nil || modelContext == nil
    }

    var body: some Commands {

        CommandGroup(after: .newItem) {
            #if DEBUG && os(macOS)
            Button("Delete Everything", systemImage: "flame") {
                guard let sde = showDeleteEverything else {
                    return
                }
                sde()
            }
            .disabled(
                showDeleteEverything == nil
            )
            #endif
            
            /// Create a new note
            Button("New Note", systemImage: "note.text.badge.plus") {
                if let vm = takeNoteVM, let mc = modelContext {
                    vm.addNote(mc)
                }
            }
            .disabled(
                takeNoteVM?.canAddNote == false || vmOrModelContextAreNil
            )
            .keyboardShortcut("N", modifiers: [.command])

            /// Create a new folder
            Button("New Folder", systemImage: "folder.badge.plus") {
                if let vm = takeNoteVM, let mc = modelContext {
                    vm.addFolder(mc)
                }
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("F", modifiers: [.command])

            /// Create a new tag
            Button("New Tag", systemImage: "tag") {
                if let vm = takeNoteVM, let mc = modelContext {
                    vm.addTag("New Tag", modelContext: mc)
                }
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("T", modifiers: [.command])

            /// Create a new tag
            Button("Empty Trash", systemImage: "trash.slash") {
                if let vm = takeNoteVM {
                    vm.showEmptyTrashAlert()
                }
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut(.delete, modifiers: [.command, .option])

        }
    }
}
