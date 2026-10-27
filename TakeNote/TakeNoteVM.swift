//
//  TakeNoteVM.swift
//  TakeNote
//
//  Created by Adam Drew on 8/21/25.
//

import Foundation
import FoundationModels
import Observation
import os
import SwiftData

enum SortBy: Int, Equatable {
    case created = 0
    case updated =  1
}

enum SortOrder: Int, Equatable {
    case oldestFirst = 0
    case newestFirst = 1
}

@MainActor
@Observable
final class TakeNoteVM {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    static let allNotesFolderName = "All Notes"
    static let archiveFolderName = "Archive"
    static let chatWindowID = "chat-window"

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "TakeNoteVM")

    // The note currently open in the editor
    var openNote: Note?
    // The folder or tag the user is viewing
    var selectedContainer: NoteContainer?
    // The notes selected in the note list
    var selectedNotes = Set<Note>()
    // The LLM we use throughout the app
    @ObservationIgnored
    private let languageModel = SystemLanguageModel.default

    var emptyTrashAlertIsPresented: Bool = false
    var linkToNoteErrorMessage: String?
    var errorAlertMessage: String?
    var orphanRecoveryAlertVisible: Bool = false
    var orphanRecoveryFolderName: String = ""
    var noteSearchText: String = ""
    // Coordination flag: set true by the search submit handler before programmatically
    // switching selectedContainer to All Notes. NoteList reads and resets it to suppress
    // the search-text-clear that would otherwise fire on that container change.
    var isSearchNavigating: Bool = false

    func searchSubmitted() {
        guard !noteSearchText.isEmpty else { return }
        isSearchNavigating = true
        selectedContainer = allNotesFolder
    }

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    func presentError(_ message: String) {
        errorAlertMessage = message
    }

    private func presentLinkError(_ message: String) {
        linkToNoteErrorMessage = message
    }

    var sortBy: SortBy {
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

    var sortOrder: SortOrder {
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
    var archiveFolder: NoteContainer?

    var navigationTitle: LocalizedStringResource {
        #if DEBUG
            "TakeNote (DEBUG)"
        #else
            "TakeNote"
        #endif
    }

    var aiIsAvailable: Bool {
        languageModel.availability == .available
    }

    // MARK: Computed Properties
    var canAddNote: Bool {
        selectedContainer?.isTrash == false
            && selectedContainer?.isTag == false
            && selectedContainer?.isStarred == false
            && selectedContainer?.isAllNotes == false
            && selectedContainer?.isArchive == false
    }

    var canRenameSelectedContainer: Bool {
        guard let sc = selectedContainer else { return false }
        if sc.isInbox || sc.isTrash || sc.isStarred || sc.isAllNotes || sc.isArchive {
            return false
        }
        return true
    }

    var bufferIsEmpty: Bool {
        bufferFolder?.notes.isEmpty ?? true
    }

    var bufferNotesCount: Int {
        bufferFolder?.notes.count ?? 0
    }

    var canEmptyTrash: Bool {
        trashFolderSelected && !selectedContainerIsEmpty
    }

    var multipleNotesSelected: Bool {
        selectedNotes.count > 1
    }

    var selectedContainerIsEmpty: Bool {
        selectedContainer?.notes.isEmpty ?? true
    }

    var trashFolderSelected: Bool {
        selectedContainer?.isTrash ?? false
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
            modelContext.delete(note)
            return nil
        }
        openNote = note
        return note
    }

    func addTag(
        _ name: String = "New Tag",
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
        }
    }

    func createArchiveFolder(_ modelContext: ModelContext) {
        if self.archiveFolder != nil { return }
        let archiveFolder = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: false,
            name: TakeNoteVM.archiveFolderName,
            symbol: "archivebox",
            isTag: false,
        )
        archiveFolder.isArchive = true
        modelContext.insert(archiveFolder)
        self.archiveFolder = archiveFolder
        do {
            try modelContext.save()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func moveNoteToArchive(_ note: Note, modelContext: ModelContext) {
        guard let archive = archiveFolder else {
            presentError(
                String(
                    localized: "Could not find the archive folder.",
                    comment: "Error shown when the app cannot move a note because the archive folder is missing."
                )
            )
            return
        }
        note.setFolder(archive)
        do {
            try modelContext.save()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func emptyTrash(_ modelContext: ModelContext) {
        emptyTrashAlertIsPresented = false
        guard let trash = trashFolder else {
            presentError(
                String(
                    localized: "Could not find the trash folder.",
                    comment: "Error shown when the app cannot empty trash because the trash folder is missing."
                )
            )
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
            presentError(
                String(
                    localized: "Updating the database after emptying the trash failed.",
                    comment: "Error shown when deleted trash notes could not be saved to persistent storage."
                )
            )
        }

        // Cull any NoteImage records that were only referenced by the now-deleted trash notes
        NoteImageManager(modelContext: modelContext).cullOrphanedImages()
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
            presentError(error.localizedDescription)
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

    func folderInit(
        _ modelContext: ModelContext,
        selectInboxOnLaunch: Bool
    ) {
        createInboxFolder(modelContext)
        createTrashFolder(modelContext)
        createBufferFolder(modelContext)
        createStarredFolder(modelContext)
        createAllNotesFolder(modelContext)
        createArchiveFolder(modelContext)
        if selectInboxOnLaunch {
            selectedContainer = inboxFolder
        }
    }

    func moveNoteToTrash(_ noteToTrash: Note, modelContext: ModelContext) {
        guard let trash = trashFolder else {
            presentError(
                String(
                    localized: "Could not find the trash folder.",
                    comment: "Error shown when the app cannot move a note to trash because the trash folder is missing."
                )
            )
            return
        }
        noteToTrash.folder = trash
        if noteToTrash.starred {
            noteStarredToggle(noteToTrash, modelContext: modelContext)
        }
        do {
            try modelContext.save()
        } catch {
            presentError(error.localizedDescription)
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
        do {
            try modelContext.save()
        } catch {
            presentError(error.localizedDescription)
        }
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

        do {
            try modelContext.save()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func loadNoteFromURL(_ url: URL, modelContext: ModelContext) {
        var notes: [Note] = []

        guard let uuid = UUID(uuidString: url.lastPathComponent) else {
            presentLinkError(
                String(
                    localized: "Invalid note link.",
                    comment: "Error shown when a TakeNote note URL cannot be parsed."
                )
            )
            return
        }

        do {
            notes = try modelContext.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate { $0.uuid == uuid }
                )
            )
        } catch {
            presentLinkError(
                String(
                    localized: "Error querying notes.",
                    comment: "Error shown when a note link could not be resolved because the note query failed."
                )
            )
            return
        }

        if notes.isEmpty {
            presentLinkError(
                String(
                    localized: "No notes matching this link were found.",
                    comment: "Error shown when a TakeNote note URL is valid but no note exists for it."
                )
            )
            return
        }

        if let note = notes.first {
            self.selectedContainer = note.folder
            self.selectedNotes = [note]
            self.openNote = note
            return
        }

        presentLinkError(
            String(
                localized: "Something went wrong opening the note link.",
                comment: "Fallback error shown when a valid note link could not be opened."
            )
        )
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
