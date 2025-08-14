//
//  MainWindowExtension.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import FoundationModels
import SwiftData
import SwiftUI

@MainActor
extension MainWindow {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    
    // MARK: Computed Properties

    var aiIsAvailable: Bool {
        return languageModel.availability == .available
    }

    var canAddNote: Bool {
        return selectedContainer?.isTrash == false
            && selectedContainer?.isTag == false
    }

    var canEmptyTrash: Bool {
        return trashFolderSelected && !selectedFolderEmpty
    }

    var inboxFolderExists: Bool {
        return !inboxFolders.isEmpty
    }

    var navigationTitle: String {
        return selectedContainer?.name ?? "TakeNote"
    }

    var selectedFolderEmpty: Bool {
        return selectedContainer?.notes.isEmpty ?? true
    }

    var trashFolderSelected: Bool {
        return selectedContainer?.isTrash ?? false
    }

    // MARK: Methods

    func addFolder() {
        let newFolder = NoteContainer(
            canBeDeleted: true,
            isTrash: false,
            isInbox: false,
            name: "New Folder"
        )
        modelContext.insert(newFolder)
        do {
            try modelContext.save()
            self.selectedContainer = newFolder
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func addNote() {
        guard let folder = selectedContainer else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        do {
            try modelContext.save()
            selectedNote = note
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func addTag() {
        addTag(name: "New Tag", color: Color(.blue))
    }

    func addTag(name: String, color: Color) {
        let newTag = NoteContainer(
            isTrash: false,
            isInbox: false,
            name: name,
            isTag: true
        )
        newTag.setColor(color)
        modelContext.insert(newTag)
        do {
            try modelContext.save()
            selectedContainer = newTag
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
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
        do {
            try modelContext.save()
            self.selectedContainer = inboxFolder
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
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
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func dataInit() {
        tagsInit()
        folderInit()
    }

    func emptyTrash() {
        emptyTrashAlertIsPresented = false
        if let trashFolder = trashFolders.first {
            for note in trashFolder.notes {
                modelContext.delete(note)
            }
        }
    }

    func folderDelete(_ deletedFolder: NoteContainer) {
        if let trashFolder = trashFolders.first {
            for note in deletedFolder.notes {
                note.folder = trashFolder
            }
        }
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
            return
        }
        if deletedFolder != selectedContainer {
            return
        }
        selectedContainer = folders.first(where: {
            $0.name == MainWindow.inboxFolderName
        })
        selectedNote = nil
    }

    func folderInit() {
        if inboxFolderExists {
            return
        }
        createInboxFolder()
        createTrashFolder()
    }

    func moveNoteToTrash(_ noteToTrash: Note) {
        guard let trashFolder = trashFolders.first else {
            return
        }
        noteToTrash.folder = trashFolder
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
            return
        }
        if selectedNote != noteToTrash {
            return
        }
        selectedNote = nil
    }

    func loadNoteFromURL(_ url: URL) {
        var notes: [Note] = []

        guard let uuid = UUID(uuidString: url.lastPathComponent) else {
            linkToNoteErrorMessage = "Invalid note link"
            linkToNoteErrorIsPresented = true
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
            linkToNoteErrorIsPresented = true
            return
        }

        if notes.isEmpty {
            linkToNoteErrorMessage = "No notes matching link found"
            linkToNoteErrorIsPresented = true
            return
        }

        if let note = notes.first {
            self.selectedNote = note
            self.selectedContainer = note.folder
            return
        }

        linkToNoteErrorMessage =
            "Something went wrong setting note from link"
        linkToNoteErrorIsPresented = true
    }

    func openChatWindow() {
        openWindow(id: "chat-window")
    }

    func showEmptyTrashAlert() {
        emptyTrashAlertIsPresented = true
    }

    func onTagDelete(_ deletedTag: NoteContainer) {
        if deletedTag == selectedContainer {
            selectedContainer = inboxFolders.first
            selectedNote = nil
        }
    }

    var tagsExist: Bool {
        return tags.isEmpty == false
    }

    func tagsInit() {
        if tagsExist {
            return
        }
        addTag(name: "🏠 Home", color: Color(.blue))
        addTag(name: "🏢 Work", color: Color(.green))
        addTag(name: "🛒 Shopping", color: Color(.purple))
        addTag(name: "❤️ Personal", color: Color(.orange))
    }

}
