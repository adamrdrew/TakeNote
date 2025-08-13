//
//  ContentView.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import FoundationModels
import SwiftData
import SwiftUI

struct ContentView: View {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    let model = SystemLanguageModel.default
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
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

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true

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

    func tagDelete(_ deletedTag: NoteContainer) {
        if deletedTag == selectedFolder {
            selectedFolder = inboxFolders.first
            selectedNote = nil
        }
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
        if inboxFolders.count != 0 {
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
        home.setColor(Color(.blue))
        let work = NoteContainer(
            name: "Work",
            isTag: true
        )
        work.setColor(Color(.green))
        let shopping = NoteContainer(
            name: "Shopping",
            isTag: true
        )
        shopping.setColor(Color(.red))
        let personal = NoteContainer(
            name: "Personal",
            isTag: true
        )
        personal.setColor(Color(.purple))
        modelContext.insert(home)
        modelContext.insert(work)
        modelContext.insert(shopping)
        modelContext.insert(personal)
        try? modelContext.save()
    }

    func addNote() {
        guard let folder = selectedFolder else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
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

    func addTag() {
        let newTag = NoteContainer(
            isTrash: false,
            isInbox: false,
            name: "New Tag",
            isTag: true
        )
        newTag.setColor(Color(.blue))
        modelContext.insert(newTag)
        try? modelContext.save()
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
            List(selection: $selectedFolder) {
                Section(
                    isExpanded: $folderSectionExpanded,
                    content: {
                        FolderList(
                            selectedFolder: $selectedFolder,
                            onDelete: folderDelete,
                            onEmptyTrash: emptyTrash
                        )
                    },
                    header: {
                        Text("Folders")
                    }
                )
                .headerProminence(.increased)

                Section(
                    isExpanded: $tagSectionExpanded,
                    content: {
                        TagList(
                            selectedFolder: $selectedFolder,
                            onDelete: tagDelete
                        )
                    },
                    header: {
                        Text("Tags")
                    }
                ).headerProminence(.increased)
            }
            .listStyle(.sidebar)
            .toolbar {
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }

                Button(action: addTag) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "tag")
                            .scaleEffect(x: -1, y: 1)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 7))
                            .offset(x: 2, y: -10)
                    }
                }
            }

        } content: {
            NoteList(
                selectedFolder: $selectedFolder,
                selectedNote: $selectedNote,
                onTrash: moveNoteToTrash
            ).toolbar {
                if model.availability == .available {

                    Button(action: { openWindow(id: "chat-window") }) {
                        Label("Chat", systemImage: "message")
                    }

                }
                if selectedFolder?.isTrash == true
                    && selectedFolder?.notes.isEmpty == false
                {
                    Button(action: showEmptyTrashAlert) {
                        Label("Empty Trash", systemImage: "trash.slash")
                    }
                }
                if selectedFolder?.isTrash == false
                    && selectedFolder?.isTag == false
                {
                    Button(action: addNote) {
                        Image(systemName: "note.text.badge.plus")
                    }

                }

            }
        } detail: {
            NoteEditor(selectedNote: $selectedNote)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300)
        .navigationTitle(selectedFolder?.name ?? "TakeNote")
        
        

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
