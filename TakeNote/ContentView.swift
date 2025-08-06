//
//  ContentView.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    static let defaultFolderName = "Inbox"
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Folder> { folder in folder.name == defaultFolderName
        }
    ) var defaultFolders: [Folder]
    @Query var folders: [Folder]

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?

    func onFolderDelete(_ deletedFolder: Folder) {
        if deletedFolder != self.selectedFolder {
            return
        }
        selectedFolder = folders.first(where: {
            $0.name == ContentView.defaultFolderName
        })
        selectedNote = nil
    }

    func folderInit() {
        if defaultFolders.count != 0 {
            return
        }
        let defaultFolder = Folder(
            canBeDeleted: false,
            name: ContentView.defaultFolderName
        )
        modelContext.insert(defaultFolder)
        try? modelContext.save()
        self.selectedFolder = defaultFolder
    }

    func addFolder() {
        let newFolder = Folder(canBeDeleted: true, name: "New Folder")
        modelContext.insert(newFolder)
        try? modelContext.save()
        self.selectedFolder = newFolder
    }

    var body: some View {
        NavigationSplitView {
            FolderList(
                selectedFolder: $selectedFolder,
                onDelete: onFolderDelete
            )
            .toolbar {
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            }
        } content: {
            NoteList(
                selectedFolder: $selectedFolder,
                selectedNote: $selectedNote,
            )
        } detail: {
            NoteEditor(selectedNote: $selectedNote)
        }
        .onAppear(perform: folderInit)
    }
}

#Preview {
    ContentView()
}
