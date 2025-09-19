//
//  TakeNoteVM.swift
//  TakeNote
//
//  Created by Adam Drew on 8/21/25.
//

import FoundationModels
import SwiftData
import SwiftUI

@Observable
@MainActor
class TakeNoteVM {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    static let chatWindowID = "chat-window"

    // The note currently open in the editor
    var openNote: Note?
    // The folder or tag the user is viewing
    var selectedContainer: NoteContainer?
    // The notes selected in the note list
    var selectedNotes = Set<Note>()
    // The LLM we use throughout the app
    let languageModel = SystemLanguageModel.default

    var emptyTrashAlertIsPresented: Bool = false
    var linkToNoteErrorIsPresented: Bool = false
    var linkToNoteErrorMessage: String = ""
    var folderSectionExpanded: Bool = true
    var tagSectionExpanded: Bool = true
    var errorAlertMessage: String = ""
    var errorAlertIsVisible: Bool = false
    var showMultiNoteView: Bool = false

    var inboxFolder: NoteContainer?
    var trashFolder: NoteContainer?
    var bufferFolder: NoteContainer?
    var starredFolder: NoteContainer?

    var navigationTitle: String {
        var title = ""
        if let selectedContainerName = selectedContainer?.name {
            title = "\(selectedContainerName)"
        }
        if let openNoteTitle = openNote?.title {
            title = "\(title) / \(openNoteTitle)"
        }
        #if DEBUG
            return "TakeNote (DEBUG)"
        #endif
        return "TakeNote"
    }

    var aiIsAvailable: Bool {
        return languageModel.availability == .available
    }

    // MARK: Computed Properties
    var canAddNote: Bool {
        return selectedContainer?.isTrash == false
            && selectedContainer?.isTag == false
    }

    var canRenameSelectedContainer: Bool {
        guard let sc = selectedContainer else { return false }
        if sc.isInbox || sc.isTrash {
            return false
        }
        return true
    }

    var bufferIsEmpty: Bool {
        return bufferFolder?.notes.isEmpty ?? true
    }

    var bufferNotesCount: Int {
        return bufferFolder?.notes.count ?? 0
    }

    var canEmptyTrash: Bool {
        return trashFolderSelected && !selectedContainerIsEmpty
    }

    var inboxFolderExists: Bool {
        return inboxFolder != nil
    }

    var multipleNotesSelected: Bool {
        return selectedNotes.count > 1
    }

    var selectedContainerIsEmpty: Bool {
        return selectedContainer?.notes.isEmpty ?? true
    }

    var trashFolderSelected: Bool {
        return selectedContainer?.isTrash ?? false
    }

    // MARK: Methods

    func addFolder(_ modelContext: ModelContext) {
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

    func addNote(_ modelContext: ModelContext) {
        guard let folder = selectedContainer else {
            print("Adding note failed, no folder selected")
            return
        }
        let note = Note(folder: folder)
        modelContext.insert(note)
        do {
            try modelContext.save()
            //selectedNotes = [note]
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func addTag(
        _ name: String = "New Tag",
        color: Color = Color(.blue),
        modelContext: ModelContext
    ) {
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

    func createInboxFolder(_ modelContext: ModelContext) {
        if self.inboxFolder != nil { return }
        let inboxFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: true,
            isStarred: false,
            name: TakeNoteVM.inboxFolderName,
            symbol: "tray",
            isTag: false,
        )
        modelContext.insert(inboxFolder)
        self.inboxFolder = inboxFolder
        do {
            try modelContext.save()
            self.selectedContainer = inboxFolder
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func createStarredFolder(_ modelContext: ModelContext) {
        if self.starredFolder != nil { return }
        let inboxFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: true,
            name: "Starred",
            symbol: "star.fill",
            isTag: false,
        )
        modelContext.insert(inboxFolder)
        self.inboxFolder = inboxFolder
        do {
            try modelContext.save()
            self.selectedContainer = inboxFolder
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func createTrashFolder(_ modelContext: ModelContext) {
        if self.trashFolder != nil { return }
        let trashFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: true,
            isInbox: false,
            isStarred: false,
            name: TakeNoteVM.trashFolderName,
            symbol: "trash",
            isTag: false,
        )
        modelContext.insert(trashFolder)
        self.trashFolder = trashFolder
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func createBufferFolder(_ modelContext: ModelContext) {
        if self.bufferFolder != nil { return }
        let bufferFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: false,
            name: "Buffer",
            symbol: "shippingbox",
            isTag: false,
        )
        bufferFolder.isBuffer = true
        modelContext.insert(bufferFolder)
        self.bufferFolder = bufferFolder
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func emptyTrash(_ modelContext: ModelContext) {
        emptyTrashAlertIsPresented = false
        guard let trash = trashFolder else {
            errorAlertMessage = "Could not find trash folder"
            errorAlertIsVisible = true
            return
        }
        for note in trash.notes {
            modelContext.delete(note)
        }
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = "Updating DB after emptying trash failed"
            errorAlertIsVisible = true
        }

    }

    func folderDelete(
        _ deletedFolder: NoteContainer,
        folders: [NoteContainer],
        modelContext: ModelContext
    ) {
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
        if deletedFolder != selectedContainer {
            return
        }
        selectedContainer = folders.first(where: {
            $0.name == TakeNoteVM.inboxFolderName
        })
        selectedNotes = []
    }

    func folderInit(_ modelContext: ModelContext) {
        createInboxFolder(modelContext)
        createTrashFolder(modelContext)
        createBufferFolder(modelContext)
        createStarredFolder(modelContext)
        #if os(macOS)
            selectedContainer = inboxFolder
        #endif
    }

    func moveNoteToTrash(_ noteToTrash: Note, modelContext: ModelContext) {
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
        if selectedNotes.first != noteToTrash {
            return
        }
        selectedNotes = []
    }

    func moveNotesFromBufferToInbox(_ modelContext: ModelContext) {
        if bufferIsEmpty {
            return
        }
        guard let bf = bufferFolder else {
            return
        }
        guard let ibx = inboxFolder else {
            return
        }
        for note: Note in Array(bf.notes) {
            note.folder = ibx
        }
        try? modelContext.save()
    }

    func noteStarredToggle(_ note: Note, modelContext: ModelContext) {
        guard let sf = starredFolder else { return }

        if note.starred {
            note.starred = false
            if let idx = sf.starredNotes?.firstIndex(where: { $0 == note }) {
                sf.starredNotes?.remove(at: idx)
            }
        } else {
            note.starred = true
            if sf.starredNotes == nil { sf.starredNotes = [] }
            sf.starredNotes?.append(note)
        }

        try? modelContext.save()
    }

    func loadNoteFromURL(_ url: URL, modelContext: ModelContext) {
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
            self.selectedNotes = [note]
            self.selectedContainer = note.folder
            return
        }

        linkToNoteErrorMessage =
            "Something went wrong setting note from link"
        linkToNoteErrorIsPresented = true
    }

    func onMoveToFolder() {
        selectedNotes.removeAll()
        openNote = nil
    }

    func onNoteSelect(_ note: Note) {
        openNote = note
    }

    func showEmptyTrashAlert() {
        emptyTrashAlertIsPresented = true
    }

    func onTagDelete(_ deletedTag: NoteContainer) {
        if deletedTag == selectedContainer {
            selectedContainer = inboxFolder
            selectedNotes = []
        }
    }

}
