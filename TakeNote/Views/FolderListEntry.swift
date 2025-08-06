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
    @State var inDeleteMode : Bool = false

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
            Image(systemName: "folder")
            if inRenameMode {
                TextField("New Folder Name", text: $newName)
                    .focused($nameInputFocused)
                    .onSubmit {
                        finishRename()
                    }
            } else {
                Text(folder.name)
                    .font(.headline)
            }
        }
        .contextMenu {
            if folder.canBeDeleted {
                Button(role: .destructive, action: {
                    inDeleteMode = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button(action: {
                startRename()
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }

        }
        .alert("Are you sure you want to delete \(folder.name)?", isPresented: $inDeleteMode) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }    }

}
