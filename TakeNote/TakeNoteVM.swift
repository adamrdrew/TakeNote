//
//  swift
//  TakeNote
//
//  Created by Adam Drew on 8/21/25.
//

import SwiftUI
import FoundationModels
import SwiftData

@Observable
@MainActor
class TakeNoteVM {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    static let chatWindowID = "chat-window"
    
    var folders: [NoteContainer]
    var tags: [NoteContainer]
    var notes: [Note]
    
    
    var modelContext : ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        folders = try! modelContext.fetch(FetchDescriptor<NoteContainer>(predicate: #Predicate { $0.isTag != true }))
        tags = try! modelContext.fetch(FetchDescriptor<NoteContainer>(predicate: #Predicate { $0.isTag != true }))
        notes = try! modelContext.fetch(FetchDescriptor<Note>())
        trashFolder = folders.first(where: { $0.isTrash })
        inboxFolder = folders.first(where: {$0.isInbox})
        dataInit()
    }
    
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
    
    var aiIsAvailable: Bool {
        return languageModel.availability == .available
    }

    // MARK: Computed Properties
    var canAddNote: Bool {
        return selectedContainer?.isTrash == false
            && selectedContainer?.isTag == false
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
    
    var tagsExist: Bool {
        return tags.isEmpty == false
    }

    var navigationTitle: String {
        return selectedContainer?.name ?? "TakeNote"
    }

    var selectedContainerIsEmpty: Bool {
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
            //selectedNotes = [note]
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
            name: TakeNoteVM.inboxFolderName,
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
            name: TakeNoteVM.trashFolderName,
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
        if deletedFolder != selectedContainer {
            return
        }
        selectedContainer = folders.first(where: {
            $0.name == TakeNoteVM.inboxFolderName
        })
        selectedNotes = []
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
        if selectedNotes.first != noteToTrash {
            return
        }
        selectedNotes = []
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
