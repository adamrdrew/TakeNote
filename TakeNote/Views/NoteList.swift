//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct NoteList: View {
    @Binding var selectedFolder: Folder?
    @Binding var selectedNote: Note?
    @Environment(\.modelContext) private var modelContext
    var onMoveToTrash: ((_ deletedNote: Note) -> Void) = {Note in}

    func addNote() {
        guard let folder = selectedFolder else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        try? modelContext.save()
    }

    var body: some View {
        Group {
            List(selection: $selectedNote) {
                if let notes = selectedFolder?.notes {
                    ForEach(notes, id: \.self) { note in
                        NoteListEntry(note: note, onTrash: onMoveToTrash)
                    }
                } else {
                    Text("No folder selected")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: addNote) {
                    Image(systemName: "note.text.badge.plus")
                }
            }
        }
    }
}
