import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import TakeNote

@Suite(.serialized)
@MainActor
struct AdaptiveLayoutTests {
    private func makeStore() throws -> ModelContainer {
        let schema = Schema([Note.self, NoteContainer.self, NoteLink.self, NoteImage.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    @Test func closingExpandedLayoutKeepsTheSelectedNoteVisible() {
        let selection = TakeNoteVM()
        let folder = NoteContainer(name: "Projects")
        let note = Note(folder: folder)
        note.editorContent = "An unfinished draft"
        selection.selectedContainer = folder
        selection.selectedNotes = [note]
        selection.openNote = note

        let window = MainWindowActions()
        window.adaptToCompactLayout(selection: selection)

        #expect(window.preferredCompactColumn == .detail)
        #expect(selection.selectedContainer === folder)
        #expect(selection.openNote === note)
        #expect(selection.selectedNotes == [note])
        #expect(note.content == "An unfinished draft")
    }

    @Test func closingExpandedLayoutKeepsMultipleSelection() {
        let selection = TakeNoteVM()
        let folder = NoteContainer(name: "Projects")
        let notes = Set([Note(folder: folder), Note(folder: folder)])
        selection.selectedContainer = folder
        selection.selectedNotes = notes

        let window = MainWindowActions()
        window.adaptToCompactLayout(selection: selection)

        #expect(window.preferredCompactColumn == .detail)
        #expect(selection.selectedNotes == notes)
    }

    @Test func closingWithOnlyAFolderSelectedShowsItsNotes() {
        let selection = TakeNoteVM()
        selection.selectedContainer = NoteContainer(name: "Projects")
        let window = MainWindowActions()
        window.preferredCompactColumn = .detail
        window.adaptToCompactLayout(selection: selection)
        #expect(window.preferredCompactColumn == .content)
    }

    @Test func closingWithoutSelectionShowsFolders() {
        let window = MainWindowActions()
        window.preferredCompactColumn = .detail
        window.adaptToCompactLayout(selection: TakeNoteVM())
        #expect(window.preferredCompactColumn == .sidebar)
    }

    @Test func closingDuringSearchKeepsResultsVisible() {
        let selection = TakeNoteVM()
        selection.noteSearchText = "working draft"
        let window = MainWindowActions()

        window.adaptToCompactLayout(selection: selection)

        #expect(window.preferredCompactColumn == .content)
        #expect(selection.noteSearchText == "working draft")
        #expect(selection.selectedContainer == nil)
    }

    @Test func editorReattachmentPreservesDraftSelectionAndMode() throws {
        let store = try makeStore()
        let folder = NoteContainer(name: "Projects")
        let note = Note(folder: folder)
        store.mainContext.insert(folder)
        store.mainContext.insert(note)
        note.content = "My working draft"
        try store.mainContext.save()

        let editor = NoteEditorActions()
        editor.update(openNote: note, modelContext: store.mainContext)
        editor.showPreview = false
        editor.position.selections = [NSRange(location: 3, length: 7)]
        editor.position.verticalScrollPosition = 120
        note.editorContent += " remains editable"

        // Folding or resizing can reattach the view to the same note repeatedly.
        for _ in 0..<3 {
            editor.update(openNote: note, modelContext: store.mainContext)
        }

        #expect(!editor.showPreview)
        #expect(editor.position.selections == [NSRange(location: 3, length: 7)])
        #expect(editor.position.verticalScrollPosition == 120)
        #expect(editor.selectedText == "working")
        #expect(note.content == "My working draft remains editable")
    }

    @Test func selectingAnotherNoteResetsOnlyTheEditorPresentation() throws {
        let store = try makeStore()
        let folder = NoteContainer(name: "Projects")
        let first = Note(folder: folder)
        let second = Note(folder: folder)
        store.mainContext.insert(folder)
        store.mainContext.insert(first)
        store.mainContext.insert(second)
        first.content = "First draft"
        second.content = "Second draft"
        try store.mainContext.save()

        let editor = NoteEditorActions()
        editor.update(openNote: first, modelContext: store.mainContext)
        editor.showPreview = false
        editor.position.selections = [NSRange(location: 0, length: 5)]
        editor.update(openNote: second, modelContext: store.mainContext)

        #expect(editor.showPreview)
        #expect(editor.selectedText.isEmpty)
        #expect(first.content == "First draft")
        #expect(second.content == "Second draft")
    }
}
