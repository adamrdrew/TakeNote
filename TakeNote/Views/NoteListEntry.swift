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
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool

    func deleteNote() {
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
            Button(action: {
                deleteNote()
            }) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: {
                startRename()
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }
        }
    }
}
