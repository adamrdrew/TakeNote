//
//  FolderListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftUI
import SwiftData

struct FolderListEntry : View {
    @Environment(\.modelContext) private var modelContext
    var folder : Folder
    @State private var inRenameMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool
    
    var body : some View {
        HStack {
            Image(systemName: "folder")
            if inRenameMode {
                TextField("New Folder Name", text: $newName)
                    .focused($nameInputFocused)
                    .onSubmit {
                        inRenameMode = false
                        folder.name = newName
                    }
            } else {
                Text(folder.name)
                    .font(.headline)
            }
        }
        .contextMenu {
            Button(action: {
                modelContext.delete(folder)
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: {
                newName = folder.name
                inRenameMode = true
                nameInputFocused = true
            }) {
                Label("Rename", systemImage: "globe")
            }
            
            
        }
    }
    
}
