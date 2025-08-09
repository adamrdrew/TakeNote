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
    
    @State private var showLinkToNoteError : Bool = false
    @State private var linkToNoteErrorMessage : String = ""

    func folderDelete(_ deletedFolder: Folder) {
        if let trashFolder = trashFolders.first {
            for note in deletedFolder.notes {
                note.folder = trashFolder
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

    func moveNoteToTrash(_ noteToTrash: Note) {
        guard let trashFolder = trashFolders.first else {
            return
        }
        noteToTrash.folder = trashFolder
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
            for note in trashFolder.notes {
                modelContext.delete(note)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            FolderList(
                selectedFolder: $selectedFolder,
                onDelete: folderDelete,
                onEmptyTrash: emptyTrash
            )
            .toolbar {
                if selectedFolder?.isTrash == true
                    && selectedFolder?.notes.isEmpty == false
                {
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
                onTrash: moveNoteToTrash
            )
        } detail: {
            NoteEditor(selectedNote: $selectedNote)
        }
        .alert(
            "Link Error: \(linkToNoteErrorMessage)",
            isPresented: $showLinkToNoteError
        ) {
            Button("OK", action: { showLinkToNoteError = false })
        }
        .alert(
            "Are you sure you want to empty the trash? This action cannot be undone.",
            isPresented: $emptyTrashAlertVisible
        ) {
            Button("Empty Trash", role: .destructive, action: emptyTrash)
            Button("Cancel", action: { emptyTrashAlertVisible = false })
        }
        .onAppear(perform: folderInit)
        .onOpenURL { url in
            var notes : [Note] = []

            guard let uuid = UUID(uuidString: url.lastPathComponent) else {
                linkToNoteErrorMessage = "Invalid note link"
                showLinkToNoteError = true
                return
            }

            do {
                notes = try modelContext.fetch(
                    FetchDescriptor<Note>(
                        predicate: #Predicate { $0.uuid == uuid }
                    )
                )
            } catch {
                linkToNoteErrorMessage = "Error querying notes."
                showLinkToNoteError = true
                return
            }
            
            if notes.isEmpty {
                linkToNoteErrorMessage = "No notes matching link found"
                showLinkToNoteError = true
                return
            }
            
            for note in notes {
                guard note.uuid == uuid else { continue }
                self.selectedNote = note
                self.selectedFolder = note.folder
                return
            }
            
            linkToNoteErrorMessage = "Something went wrong setting note from link"
            showLinkToNoteError = true
        }
    }
}

#Preview {
    ContentView()
}
