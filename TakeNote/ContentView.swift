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
    static let trashFolderName = "Trash"
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Folder> { folder in folder.name == defaultFolderName
        }
    ) var defaultFolders: [Folder]
    @Query(
        filter: #Predicate<Folder> { folder in folder.name == trashFolderName
        }
    ) var trashFolders: [Folder]
    @Query var folders: [Folder]

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?

    func onFolderDelete(_ deletedFolder: Folder) {
        if let trashFolder = trashFolders.first {
            for note in deletedFolder.notes {
                trashFolder.notes.append(note)
            }
        }
        if deletedFolder != selectedFolder {
            return
        }
        selectedFolder = folders.first(where: {
            $0.name == ContentView.defaultFolderName
        })
        selectedNote = nil
    }

    func onNoteDelete(_ deletedNote: Note) {
        if let folder = selectedFolder {
            folder.notes.removeAll { $0 == deletedNote }
        }
        trashFolders.first?.notes.append(deletedNote)
        if selectedNote != deletedNote {
            return
        }
        selectedNote = nil
    }

    func folderInit() {
        if defaultFolders.count != 0 {
            return
        }
        createDefaultFolder()
        createTrashFolder()
    }

    private func createDefaultFolder() {
        let defaultFolder = Folder(
            canBeDeleted: false,
            isTrash: false,
            name: ContentView.defaultFolderName
        )
        modelContext.insert(defaultFolder)
        try? modelContext.save()
        self.selectedFolder = defaultFolder
    }

    private func createTrashFolder() {
        let trashFolder = Folder(
            canBeDeleted: false,
            isTrash: true,
            name: ContentView.trashFolderName,
            symbol: "trash"
        )
        modelContext.insert(trashFolder)
        try? modelContext.save()
    }

    func addFolder() {
        let newFolder = Folder(
            canBeDeleted: true,
            isTrash: false,
            name: "New Folder"
        )
        modelContext.insert(newFolder)
        try? modelContext.save()
        self.selectedFolder = newFolder
    }

    func emptyTrash() {
        if let trashFolder = trashFolders.first {
            trashFolder.notes.removeAll()
            try? modelContext.save()
        }
    }
    
    var body: some View {
        NavigationSplitView {
            FolderList(
                selectedFolder: $selectedFolder,
                onDelete: onFolderDelete
            )
            .toolbar {
                if selectedFolder?.name == ContentView.trashFolderName && (selectedFolder?.notes.isEmpty ?? true) == false {
                    Button(action: emptyTrash) {
                        Label("Empty Trash", systemImage: "trash.slash")
                    }
                }
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            }
        } content: {
            NoteList(
                selectedFolder: $selectedFolder,
                selectedNote: $selectedNote,
                onDelete: onNoteDelete
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
