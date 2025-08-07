//
//  FolderListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI

struct FolderListEntry: View {
    @Environment(\.modelContext) private var modelContext
    var folder: Folder
    @State private var inRenameMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool
    var onDelete: ((_ deletedFolder: Folder) -> Void) = { deletedFolder in }
    @State var inDeleteMode: Bool = false

    func deleteFolder() {
        onDelete(folder)
        modelContext.delete(folder)
        try? modelContext.save()
    }

    func startRename() {
        inRenameMode = true
        newName = folder.name
        nameInputFocused = true
    }

    func finishRename() {
        inRenameMode = false
        folder.name = newName
        try? modelContext.save()
    }

    func dropNoteToFolder(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id
            
            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }

            // Add the destination folder to the note and save
            note.folder = folder
            do {
                try modelContext.save()
            } catch {
                return
            }
            
        }
    }

    var body: some View {
        HStack {
            if inRenameMode {
                TextField("New Folder Name", text: $newName)
                    .focused($nameInputFocused)
                    .onSubmit {
                        finishRename()
                    }
            } else {
                Label(folder.name, systemImage: folder.symbol)
                    .font(.headline)
            }
        }
        .dropDestination(for: NoteIDWrapper.self, isEnabled: true) {
            wrappedIDs,
            _ in
            dropNoteToFolder(wrappedIDs)
        }
        .contextMenu {
            if folder.canBeDeleted {
                Button(
                    role: .destructive,
                    action: {
                        inDeleteMode = true
                    }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button(action: {
                startRename()
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }

        }
        .alert(
            "Are you sure you want to delete \(folder.name)? Notes in this folder will be moved to the trash.",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }
    }

}
