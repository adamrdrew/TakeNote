//
//  MainWindowExtension.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import FoundationModels
import SwiftData
import SwiftUI

extension MainWindow {
    
    var inboxFolderExists : Bool {
        return !inboxFolders.isEmpty
    }
    
    var aiIsAvailable: Bool {
        return model.availability == .available
    }

    var trashFolderSelected: Bool {
        return selectedFolder?.isTrash ?? false
    }

    var selectedNotFolderEmpty: Bool {
        return selectedFolder?.notes.isEmpty == false
    }

    var canAddNote: Bool {
        return selectedFolder?.isTrash == false
            && selectedFolder?.isTag == false
    }

    var canEmptyTrash: Bool {
        return trashFolderSelected && selectedNotFolderEmpty
    }

    var navigationTitle: String {
        return selectedFolder?.name ?? "TakeNote"
    }
    
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
            $0.name == MainWindow.inboxFolderName
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
        if inboxFolderExists {
            return
        }
        createInboxFolder()
        createTrashFolder()
    }

    var tagsExist: Bool {
        return tags.isEmpty == false
    }
    
    func tagsInit() {
        if tagsExist {
            return
        }
        let home = NoteContainer(
            name: "🏠 Home",
            isTag: true
        )
        home.setColor(Color(.blue))
        let work = NoteContainer(
            name: "🏢 Work",
            isTag: true
        )
        work.setColor(Color(.green))
        let shopping = NoteContainer(
            name: "🛒 Shopping",
            isTag: true
        )
        shopping.setColor(Color(.red))
        let personal = NoteContainer(
            name: "❤️ Personal",
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
            name: MainWindow.inboxFolderName,
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
            name: MainWindow.trashFolderName,
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
        emptyTrashAlertIsVisible = true
    }

    func emptyTrash() {
        emptyTrashAlertIsVisible = false
        if let trashFolder = trashFolders.first {
            for note in trashFolder.notes {
                modelContext.delete(note)
            }
        }
    }

    func openChatWindow() {
        openWindow(id: "chat-window")
    }

    func loadNoteFromURL(_ url: URL) {
        var notes: [Note] = []

        guard let uuid = UUID(uuidString: url.lastPathComponent) else {
            linkToNoteErrorMessage = "Invalid note link"
            linkToNoteErrorIsVisible = true
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
            linkToNoteErrorIsVisible = true
            return
        }

        if notes.isEmpty {
            linkToNoteErrorMessage = "No notes matching link found"
            linkToNoteErrorIsVisible = true
            return
        }

        if let note = notes.first {
            self.selectedNote = note
            self.selectedFolder = note.folder
            return
        }

        linkToNoteErrorMessage =
            "Something went wrong setting note from link"
        linkToNoteErrorIsVisible = true
    }
}
