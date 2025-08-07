//
//  ContentView.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Folder> { folder in folder.isInbox
        }
    ) var inboxFolders: [Folder]
    @Query(
        filter: #Predicate<Folder> { folder in folder.isTrash
        }
    ) var trashFolders: [Folder]
    @Query var folders: [Folder]

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?
    @State private var emptyTrashAlertVisible: Bool = false

    func onFolderDelete(_ deletedFolder: Folder) {
        if let trashFolder = trashFolders.first {
            for note in deletedFolder.notes {
                trashFolder.notes.append(note)
            }
            try? modelContext.save()
        }
        if deletedFolder != selectedFolder {
            return
        }
        selectedFolder = folders.first(where: {
            $0.name == ContentView.inboxFolderName
        })
        selectedNote = nil
    }

    func onMoveNoteToTrash(_ noteToTrash: Note) {
        if let folder = selectedFolder {
            folder.notes.removeAll { $0 == noteToTrash }
        }
        var trashFolder = trashFolders.first
        if trashFolder == nil {
            createTrashFolder()
            trashFolder = trashFolders.first
        }
        trashFolder?.notes.append(noteToTrash)
        try? modelContext.save()
        if selectedNote != noteToTrash {
            return
        }
        selectedNote = nil
    }

    func folderInit() {
        if inboxFolders.count != 0 {
            return
        }
        createInboxFolder()
        createTrashFolder()
    }

    private func createInboxFolder() {
        let inboxFolder = Folder(
            canBeDeleted: false,
            isTrash: false,
            isInbox: true,
            name: ContentView.inboxFolderName,
            symbol: "tray"
        )
        modelContext.insert(inboxFolder)
        try? modelContext.save()
        self.selectedFolder = inboxFolder
    }

    private func createTrashFolder() {
        let trashFolder = Folder(
            canBeDeleted: false,
            isTrash: true,
            isInbox: false,
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
            isInbox: false,
            name: "New Folder"
        )
        modelContext.insert(newFolder)
        try? modelContext.save()
        self.selectedFolder = newFolder
    }

    func showEmptyTrashAlert() {
        emptyTrashAlertVisible = true
    }
    
    func emptyTrash() {
        emptyTrashAlertVisible = false
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
                if selectedFolder?.isTrash == true && selectedFolder?.notes.isEmpty == false {
                    Button(action: showEmptyTrashAlert) {
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
                onMoveToTrash: onMoveNoteToTrash
            )
        } detail: {
            NoteEditor(selectedNote: $selectedNote)
        }
        .alert("Are you sure you want to empty the trash? This action cannot be undone.", isPresented: $emptyTrashAlertVisible) {
            Button("Empty Trash", role: .destructive, action: emptyTrash)
            Button("Cancel", action: { emptyTrashAlertVisible = false })
        }
        .onAppear(perform: folderInit)
    }
}

#Preview {
    ContentView()
}
