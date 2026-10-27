//
//  FileCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/23/25.
//

import SwiftData
import SwiftUI

struct FileCommands: Commands {
    @FocusedValue(TakeNoteVM.self) private var takeNoteVM: TakeNoteVM?
    @FocusedValue(SearchIndexService.self) private var search:
        SearchIndexService?
    @FocusedValue(\.modelContext) private var modelContext: ModelContext?
    @FocusedValue(\.mainWindowActions) private var mainWindowActions:
        MainWindowActions?

    private var vmOrModelContextAreNil: Bool {
        takeNoteVM == nil || modelContext == nil
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            #if DEBUG && os(macOS)
            Button("Delete Everything", systemImage: "flame") {
                mainWindowActions?.showDeleteEverything()
            }
            .disabled(
                mainWindowActions == nil
            )
            #endif

            Button("New Note", systemImage: "note.text.badge.plus") {
                if let vm = takeNoteVM, let mc = modelContext {
                    if let newNote = vm.addNote(mc) {
                        search?.reindex(note: newNote)
                    }
                }
            }
            .disabled(
                takeNoteVM?.canAddNote == false || vmOrModelContextAreNil
            )
            .keyboardShortcut("N", modifiers: [.command])

            Button("New Folder", systemImage: "folder.badge.plus") {
                if let vm = takeNoteVM, let mc = modelContext {
                    vm.addFolder(mc)
                }
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("F", modifiers: [.command])

            Button("New Tag", systemImage: "tag") {
                if let vm = takeNoteVM, let mc = modelContext {
                    vm.addTag("New Tag", modelContext: mc)
                }
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut("T", modifiers: [.command])

            Button("Empty Trash", systemImage: "trash.slash") {
                takeNoteVM?.showEmptyTrashAlert()
            }
            .disabled(
                vmOrModelContextAreNil
            )
            .keyboardShortcut(.delete, modifiers: [.command, .option])

        }
    }
}
