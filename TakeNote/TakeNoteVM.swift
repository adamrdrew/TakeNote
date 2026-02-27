//
//  TakeNoteVM.swift
//  TakeNote
//
//  Created by Adam Drew on 8/21/25.
//

import FoundationModels
import os
import SwiftData
import SwiftUI

enum SortBy : Int {
    case created = 0
    case updated =  1
}

enum SortOrder : Int {
    case oldestFirst = 0
    case newestFirst = 1
}

@Observable
@MainActor
class TakeNoteVM {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    static let allNotesFolderName = "All Notes"
    static let chatWindowID = "chat-window"

    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "TakeNoteVM")

    // The note currently open in the editor
    var openNote: Note?
    // The folder or tag the user is viewing
    var selectedContainer: NoteContainer?
    // The notes selected in the note list
    var selectedNotes = Set<Note>()
    // The LLM we use throughout the app
    let languageModel = SystemLanguageModel.default

    // MARK: Search State
    var searchQuery: String = ""
    var searchIsActive: Bool { return !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func activateSearch(query: String) {
        guard let allNotes = allNotesFolder else { return }
        selectedContainer = allNotes
        searchQuery = query
    }

    func clearSearch() {
        searchQuery = ""
    }

    var emptyTrashAlertIsPresented: Bool = false
    var linkToNoteErrorIsPresented: Bool = false
    var linkToNoteErrorMessage: String = ""
    var folderSectionExpanded: Bool = true
    var tagSectionExpanded: Bool = true
    var errorAlertMessage: String = ""
    var errorAlertIsVisible: Bool = false
    var showMultiNoteView: Bool = false
    
    let userDefaults = UserDefaults.standard
    
    public var sortBy: SortBy {
            get {
                access(keyPath: \.sortBy)
                let raw = userDefaults.object(forKey: "SortBy") as? Int
                return SortBy(rawValue: raw ?? SortBy.created.rawValue) ?? .created
            }
            set {
                withMutation(keyPath: \.sortBy) {
                    userDefaults.set(newValue.rawValue, forKey: "SortBy")
                }
            }
        }

        public var sortOrder: SortOrder {
            get {
                access(keyPath: \.sortOrder)
                let raw = userDefaults.object(forKey: "SortOrder") as? Int
                return SortOrder(rawValue: raw ?? SortOrder.newestFirst.rawValue) ?? .newestFirst
            }
            set {
                withMutation(keyPath: \.sortOrder) {
                    userDefaults.set(newValue.rawValue, forKey: "SortOrder")
                }
            }
        }
    
    
    var inboxFolder: NoteContainer?
    var trashFolder: NoteContainer?
    var bufferFolder: NoteContainer?
    var starredFolder: NoteContainer?
    var allNotesFolder: NoteContainer?

    var navigationTitle: String {
        #if DEBUG
            return "TakeNote (DEBUG)"
        #else
            return "TakeNote"
        #endif
    }

    var aiIsAvailable: Bool {
        return languageModel.availability == .available
    }

    // MARK: Computed Properties
    var canAddNote: Bool {
        return selectedContainer?.isTrash == false
            && selectedContainer?.isTag == false
            && selectedContainer?.isStarred == false
            && selectedContainer?.isAllNotes == false
    }

    var canRenameSelectedContainer: Bool {
        guard let sc = selectedContainer else { return false }
        if sc.isInbox || sc.isTrash || sc.isStarred || sc.isAllNotes {
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

    func addNote(_ modelContext: ModelContext) -> Note? {
        guard let folder = selectedContainer else {
            logger.warning("addNote called with no selected container")
            return nil
        }
        let note = Note(folder: folder)
        modelContext.insert(note)
        do {
            try modelContext.save()
            selectedNotes = [note]
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
        openNote = note
        return note
    }

    func addTag(
        _ name: String = "New Tag",
        color: Color = .takeNotePink,
        modelContext: ModelContext
    ) {
        let newTag = NoteContainer(
            isTrash: false,
            isInbox: false,
            name: name,
            symbol: "tag.fill",
            isTag: true
        )
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
        } catch {
            errorAlertMessage = error.localizedDescription
            errorAlertIsVisible = true
        }
    }

    func createStarredFolder(_ modelContext: ModelContext) {
        if self.starredFolder != nil { return }
        let starredFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: true,
            name: "Starred",
            symbol: "star.fill",
            isTag: false,
        )
        modelContext.insert(starredFolder)
        self.starredFolder = starredFolder
        do {
            try modelContext.save()
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

    func createAllNotesFolder(_ modelContext: ModelContext) {
        if self.allNotesFolder != nil { return }
        let allNotesFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: false,
            name: TakeNoteVM.allNotesFolderName,
            symbol: "text.pad.header",
            isTag: false,
        )
        allNotesFolder.isAllNotes = true
        modelContext.insert(allNotesFolder)
        self.allNotesFolder = allNotesFolder
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
            if openNote == note {
                openNote = nil
            }
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
        for note in deletedFolder.notes {
            moveNoteToTrash(note, modelContext: modelContext)
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
        createAllNotesFolder(modelContext)
        #if os(macOS)
            selectedContainer = inboxFolder
        #endif
        #if os(iOS)
        // on iphone we don't want a selected container on start so that it starts on the note container list page
        // we want ipad however to work more like a mac
            if UIDevice.current.userInterfaceIdiom == .pad {
                selectedContainer = inboxFolder
            }
        #endif
    }

    func moveNoteToTrash(_ noteToTrash: Note, modelContext: ModelContext) {
        guard let trash = trashFolder else {
            errorAlertMessage = "Could not find trash folder"
            errorAlertIsVisible = true
            return
        }
        noteToTrash.folder = trash
        if noteToTrash.starred {
            noteStarredToggle(noteToTrash, modelContext: modelContext)
        }
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
            if !(sf.starredNotes ?? []).contains(note) {
                sf.starredNotes?.append(note)
            }
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
