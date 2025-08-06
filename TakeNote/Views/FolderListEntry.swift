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

    func deleteFolder() {
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
                Button(action: {
                    deleteFolder()
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
    }

}
