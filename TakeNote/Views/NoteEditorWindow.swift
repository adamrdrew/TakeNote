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

    @State var note: Note?

    @Environment(\.modelContext) private var modelContext

    private func makeWindowTitle() -> String {
        var noteTitle: String = ""
        var folderName: String = ""
        let appName = "TakeNote"

        guard let note = note else {
            return appName
        }

        folderName = note.folder.name

        noteTitle = note.title
        return "\(appName) - \(folderName)/\(noteTitle)"
    }

    private func getNote() {
        guard let id = noteID?.id else {
            return
        }

        // Retrieve the note by ID
        guard let loadedNote = modelContext.model(for: id) as? Note else {
            return
        }

        note = loadedNote
    }

    var body: some View {

        NoteEditor(selectedNote: $note)
            .onAppear {
                getNote()
            }
            .navigationTitle(makeWindowTitle())

    }

}
