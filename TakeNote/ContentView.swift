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
        filter: #Predicate<NoteContainer> { folder in folder.isInbox
        }
    ) var inboxFolders: [NoteContainer]
    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTrash
        }
    ) var trashFolders: [NoteContainer]
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    @State private var selectedFolder: NoteContainer?
    @State private var selectedNote: Note?
    @State private var emptyTrashAlertVisible: Bool = false

    @State private var showLinkToNoteError: Bool = false
    @State private var linkToNoteErrorMessage: String = ""

    func folderDelete(_ deletedFolder: NoteContainer) {
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

    func dataInit() {
        folderInit()
        tagsInit()
    }

    func folderInit() {
        if inboxFolders.count != 0  {
            return
        }
        createInboxFolder()
        createTrashFolder()
    }

    func tagsInit() {
        guard tags.count == 0 else {
            return
        }
        let home = NoteContainer(
            name: "Home",
            isTag: true
        )
        let work = NoteContainer(
            name: "Work",
            isTag: true
        )
        work.setColor(red: 0.034, green: 0.230, blue: 0.096)
        let shopping = NoteContainer(
            name: "Shopping",
            isTag: true
        )
        shopping.setColor(red: 0.158, green: 0.034, blue: 0.230)
        let personal = NoteContainer(
            name: "Personal",
            isTag: true
        )
        personal.setColor(red: 0.23, green: 0.01, blue: 0.40)
        modelContext.insert(home)
        modelContext.insert(work)
        modelContext.insert(shopping)
        modelContext.insert(personal)
        try? modelContext.save()
    }

    private func createInboxFolder() {
        let inboxFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: true,
            name: ContentView.inboxFolderName,
            symbol: "tray",
            isTag: false,
        )
        modelContext.insert(inboxFolder)
        try? modelContext.save()
        self.selectedFolder = inboxFolder
    }

    private func createTrashFolder() {
        let trashFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: true,
            isInbox: false,
            name: ContentView.trashFolderName,
            symbol: "trash",
            isTag: false,
        )
        modelContext.insert(trashFolder)
        try? modelContext.save()
    }

    func addFolder() {
        let newFolder = NoteContainer(
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
            VStack {
                Section(header: Text("Home")) {
                    FolderList(
                        selectedFolder: $selectedFolder,
                        onDelete: folderDelete,
                        onEmptyTrash: emptyTrash
                    )
                }

                Section(header: Text("Tags")) {
                    TagList(
                        selectedFolder: $selectedFolder
                    )
                }
            }
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
        .onAppear(perform: dataInit)
        .onOpenURL { url in
            var notes: [Note] = []

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

            if let note = notes.first {
                self.selectedNote = note
                self.selectedFolder = note.folder
                return
            }

            linkToNoteErrorMessage =
                "Something went wrong setting note from link"
            showLinkToNoteError = true
        }
    }
}

#Preview {
    ContentView()
}
