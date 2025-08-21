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
        return takeNoteVM.selectedContainer?.isTrash == false
            && takeNoteVM.selectedContainer?.isTag == false
    }

    var canEmptyTrash: Bool {
        return trashFolderSelected && !selectedContainerIsEmpty
    }

    var inboxFolderExists: Bool {
        return inboxFolder != nil
    }

    var multipleNotesSelected: Bool {
        return takeNoteVM.selectedNotes.count > 1
    }
    
    var tagsExist: Bool {
        return tags.isEmpty == false
    }

    var navigationTitle: String {
        return takeNoteVM.selectedContainer?.name ?? "TakeNote"
    }

    var selectedContainerIsEmpty: Bool {
        return takeNoteVM.selectedContainer?.notes.isEmpty ?? true
    }

    var trashFolderSelected: Bool {
        return takeNoteVM.selectedContainer?.isTrash ?? false
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
            self.takeNoteVM.selectedContainer = newFolder
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func addNote() {
        guard let folder = takeNoteVM.selectedContainer else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        do {
            try modelContext.save()
            //takeNoteVM.selectedNotes = [note]
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
            takeNoteVM.selectedContainer = newTag
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
            self.takeNoteVM.selectedContainer = inboxFolder
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
        folderInit()
    }

    func emptyTrash() {
        emptyTrashAlertIsPresented = false
        guard let trash = trashFolder else {
            errorAlertMessage = "Could not find trash folder"
            errorAlertIsVisible = true
            return
        }
        for note in trash.notes {
            modelContext.delete(note)
        }
    }

    func folderDelete(_ deletedFolder: NoteContainer) {
        guard let trash = trashFolder else {
            errorAlertMessage = "Could not find trash folder"
            errorAlertIsVisible = true
            return
        }
        for note in deletedFolder.notes {
            note.folder = trash
        }
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
            return
        }
        if deletedFolder != takeNoteVM.selectedContainer {
            return
        }
        takeNoteVM.selectedContainer = folders.first(where: {
            $0.name == MainWindow.inboxFolderName
        })
        takeNoteVM.selectedNotes = []
    }

    func folderInit() {
        if inboxFolderExists {
            return
        }
        createInboxFolder()
        createTrashFolder()
    }

    func moveNoteToTrash(_ noteToTrash: Note) {
        guard let trash = trashFolder else {
            errorAlertMessage = "Could not find trash folder"
            errorAlertIsVisible = true
            return
        }
        noteToTrash.folder = trash
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
            return
        }
        if takeNoteVM.selectedNotes.first != noteToTrash {
            return
        }
        takeNoteVM.selectedNotes = []
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
            self.takeNoteVM.selectedNotes = [note]
            self.takeNoteVM.selectedContainer = note.folder
            return
        }

        linkToNoteErrorMessage =
            "Something went wrong setting note from link"
        linkToNoteErrorIsPresented = true
    }

    func onMoveToFolder() {
        takeNoteVM.selectedNotes.removeAll()
        takeNoteVM.openNote = nil
    }
    
    func onNoteSelect(_ note: Note) {
        takeNoteVM.openNote = note
    }
    
    func openChatWindow() {
        openWindow(id: "chat-window")
    }

    func showEmptyTrashAlert() {
        emptyTrashAlertIsPresented = true
    }

    func onTagDelete(_ deletedTag: NoteContainer) {
        if deletedTag == takeNoteVM.selectedContainer {
            takeNoteVM.selectedContainer = inboxFolder
            takeNoteVM.selectedNotes = []
        }
    }

}
