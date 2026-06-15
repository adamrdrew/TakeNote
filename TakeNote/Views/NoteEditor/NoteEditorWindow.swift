//
//  NoteEditorWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/8/25.
//

import SwiftData
import SwiftUI

struct NoteEditorWindow: View {
    @Binding var noteID: NoteIDWrapper?

    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) private var editorWindowVM
    @Environment(SearchIndexService.self) private var search

    private var windowTitle: String {
        let appName = "TakeNote"

        guard let note = editorWindowVM.openNote else {
            return appName
        }

        let folderName = note.folder?.name ?? String(localized: "No Folder")
        return "\(appName) / \(folderName) / \(note.title)"
    }

    private func getNote() {
        guard let id = noteID?.id else {
            return
        }

        // Retrieve the note by ID
        guard let loadedNote = modelContext.model(for: id) as? Note else {
            return
        }

        editorWindowVM.openNote = loadedNote
    }

    var body: some View {
        @Bindable var editorWindowVM = editorWindowVM
        NoteEditor(
            openNote: $editorWindowVM.openNote
        )
            .onAppear {
                getNote()
            }
            .onChange(of: editorWindowVM.openNote) { oldNote, _ in
                if let note = oldNote {
                    search.reindex(note: note)
                }
            }
            .onDisappear {
                if let note = editorWindowVM.openNote {
                    search.reindex(note: note)
                }
            }
            .navigationTitle(windowTitle)

    }

}
