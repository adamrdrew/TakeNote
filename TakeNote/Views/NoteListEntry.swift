//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI

struct NoteListEntry: View {
    @Environment(\.modelContext) private var modelContext
    var note: Note
    @State private var inRenameMode: Bool = false
    @State private var inDeleteMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool
    var onDelete : ((_ note: Note) -> Void) = { note in }
    
    func deleteNote() {
        onDelete(note)
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    func startRename() {
        inRenameMode = true
        newName = note.title
        nameInputFocused = true
    }

    func finishRename() {
        inRenameMode = false
        note.title = newName
        try? modelContext.save()
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "note.text")
                if inRenameMode {
                    TextField("New Folder Name", text: $newName)
                        .focused($nameInputFocused)
                        .onSubmit {
                            finishRename()
                        }
                } else {
                    Text(note.title)
                        .font(.headline)
                }

            }
            Text(note.createdDate, style: .date)
        }
        .padding(10)
        .contextMenu {
            Button(role: .destructive, action: {
                inDeleteMode = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: {
                startRename()
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }
        }
        .alert("Are you sure you want to delete \(note.title)?", isPresented: $inDeleteMode) {
            Button("Delete", role: .destructive) {
                deleteNote()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }
    }
}
