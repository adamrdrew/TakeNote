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
            // Bail if we don't have an ID
            guard let id = wrappedIDs.first?.id else {
                return
            }

            // Get an array of notes that match the persistentModelId
            let notes = try? modelContext.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate { $0.persistentModelID == id },
                    sortBy: [
                        .init(\.createdDate)
                    ]
                )
            )

            // Bail if there is no note to move
            guard let note = notes?.first else {
                return
            }
                        
            let sourceFolder = note.folder

            // Remove the note from the source folder and save
            sourceFolder.notes.remove(
                at: sourceFolder.notes.firstIndex(of: note)!
            )
            try? modelContext.save()

            // Add the destination folder to the note and save
            note.folder = folder
            try? modelContext.save()
            
            // Add the note to the destination folder and save
            folder.notes.append(note)
            try? modelContext.save()

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
