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
    var onTrash: ((_ deletedNote: Note) -> Void) = { Note in }

    func addNote() {
        guard let folder = selectedFolder else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        try? modelContext.save()
    }

    func folderHasStarredNotes() -> Bool {
        return selectedFolder?.notes.map { $0.starred }.contains(true) ?? false
    }

    var body: some View {
        Group {
            if let notes = selectedFolder?.notes {
                List(selection: $selectedNote) {

                    if folderHasStarredNotes() {
                        Section(header: Text("Starred")) {
                            ForEach(notes, id: \.self) { note in
                                if note.starred {
                                    NoteListEntry(
                                        note: note,
                                        selectedFolder: selectedFolder,
                                        onTrash: onTrash
                                    )

                                }
                            }
                        }

                    }
                    Section(header: Text(selectedFolder?.name ?? "Notes")) {
                        ForEach(notes, id: \.self) { note in
                            if !note.starred {
                                NoteListEntry(
                                    note: note,
                                    selectedFolder: selectedFolder,
                                    onTrash: onTrash
                                )
                            }

                        }
                    }
                }

            } else {
                Text("No folder selected")
            }
        }
        .toolbar {
            ToolbarItem {
                if selectedFolder?.isTrash == false {
                    Button(action: addNote) {
                        Image(systemName: "note.text.badge.plus")
                    }
                }
            }
        }
    }
}
