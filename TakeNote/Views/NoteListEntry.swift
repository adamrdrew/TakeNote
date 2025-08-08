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
    @Environment(\.openWindow) private var openWindow

    var note: Note
    var selectedFolder: Folder?
    var onTrash: ((_ deletedNote: Note) -> Void) = { Note in }
    @State private var inRenameMode: Bool = false
    @State private var inMoveToTrashMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool

    func openEditorWindow() {
        openWindow(id: "note-editor-window", value: NoteIDWrapper(id: note.persistentModelID))
    }
    
    func moveToTrash() {
        onTrash(note)
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
            VStack {
                if inRenameMode {
                    TextField("New Note Name", text: $newName)
                        .focused($nameInputFocused)
                        .onSubmit {
                            finishRename()
                        }
                } else {
                    VStack {
                        HStack {
                            Label(note.title, systemImage: "note.text")
                                .font(.headline)
                            Spacer()
                            Button(
                                "",
                                systemImage: note.starred ? "star.fill" : "star"
                            ) {
                                note.starred = !note.starred
                                try? modelContext.save()
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(note.starred ? .yellow : .secondary)

                        }

                        Text(note.createdDate, style: .date)
                    }

                }

            }

        }
        .onTapGesture(count: 2) {
            openEditorWindow()
        }
        .draggable(NoteIDWrapper(id: note.persistentModelID))
        .padding(10)
        .contextMenu {
            if selectedFolder?.isTrash == false {
                Button(
                    role: .destructive,
                    action: {
                        inMoveToTrashMode = true
                    }
                ) {
                    Label("Move to Trash", systemImage: "trash")
                }
                Button(action: {
                    startRename()
                }) {
                    Label("Rename", systemImage: "square.and.pencil")
                }
            }
            Button(
                action: {
                    openEditorWindow()
                }
            ) {
                Label("Open Editor Window", systemImage: "macwindow")
            }
        }
        .alert(
            "Are you sure you want to move \(note.title) to the trash?",
            isPresented: $inMoveToTrashMode
        ) {
            Button("Move to Trash", role: .destructive) {
                moveToTrash()
            }
            Button("Cancel", role: .cancel) {
                inMoveToTrashMode = false
            }
        }
    }
}
