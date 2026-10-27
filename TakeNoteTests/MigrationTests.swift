import CoreSpotlight
import Foundation
import SwiftData
import Testing
@testable import TakeNote

@Suite(.serialized)
@MainActor
struct MigrationTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Note.self, NoteContainer.self, NoteLink.self, NoteImage.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    @Test(arguments: [
        "Create a note about lunch", "Please write a new note", "Could you save that as a note?",
        "Make notes about this meeting", "Add a note", "Compose a markdown note"
    ])
    func explicitCreationRequestsAllowWriting(_ request: String) {
        #expect(ChatRequest.allowsNoteCreation(request))
    }

    @Test(arguments: [
        "What notes did I write?", "Find my notes about saved recipes", "Don't create a note",
        "How do I create notes?", "Summarize my notes", "Find notes about additive manufacturing",
        "Create a summary of my notes", "What does my notebook say about makeup?"
    ])
    func questionsAndNegationsCannotEnableWriting(_ request: String) {
        #expect(!ChatRequest.allowsNoteCreation(request))
    }

    @Test func conversationSurvivesChangesInToolAccess() {
        let history = [
            ConversationEntry(sender: .human, text: "What are my pasta recipes?"),
            ConversationEntry(sender: .bot, text: "You have lasagna and pesto.")
        ]
        let prompt = ChatRequest.prompt("Save that as a note", context: nil, history: history)
        #expect(prompt.contains("You have lasagna and pesto."))
        #expect(prompt.contains("Current request:\nSave that as a note"))
        #expect(ChatRequest.allowsNoteCreation("Save that as a note"))
        #expect(!ChatRequest.allowsNoteCreation("What was in that note?"))
    }

    @Test func assistantReceivesSelectionAndCurrentRequest() {
        let prompt = ChatRequest.prompt("Make this bold", context: "selected text", history: [])
        #expect(prompt.contains("CONTEXT:\nselected text"))
        #expect(prompt.contains("Current request:\nMake this bold"))
        #expect(!prompt.contains("Earlier conversation"))
    }

    @Test func folderIdentitySurvivesRenameAndDuplicateNames() throws {
        let store = try container()
        let context = store.mainContext
        let first = NoteContainer(name: "Projects")
        let second = NoteContainer(name: "Projects")
        context.insert(first)
        context.insert(second)
        try context.save()
        let entity = try NoteFolderEntity(container: first)
        #expect(entity.id != (try NoteFolderEntity(container: second)).id)
        first.name = "Work"
        try context.save()
        #expect(entity.id == (try NoteFolderEntity(container: first)).id)
        let reopenedContext = ModelContext(store)
        let resolved = try TakeNoteIntentStore.folder(for: entity, in: reopenedContext)
        #expect(resolved.name == "Work")
        #expect(resolved.persistentModelID == first.persistentModelID)
    }

    @Test func tagIdentitySurvivesRenameAndDuplicateNames() throws {
        let store = try container()
        let context = store.mainContext
        let first = NoteContainer(name: "Ideas", isTag: true)
        let second = NoteContainer(name: "Ideas", isTag: true)
        context.insert(first)
        context.insert(second)
        try context.save()
        let entity = try NoteTagEntity(container: first)
        #expect(entity.id != (try NoteTagEntity(container: second)).id)
        first.name = "Plans"
        try context.save()
        #expect(try TakeNoteIntentStore.tag(for: entity, in: context) === first)
        #expect(entity.id == (try NoteTagEntity(container: first)).id)
    }

    @Test func protectedFoldersCannotBeEditedByIntents() throws {
        let folder = NoteContainer(canBeDeleted: false, isInbox: true, name: "Inbox")
        #expect(throws: TakeNoteIntentError.self) {
            try TakeNoteIntentStore.requireEditableFolder(folder)
        }
        try TakeNoteIntentStore.requireEditableFolder(NoteContainer(name: "Custom"))
    }

    @Test func intentsCanResolveSystemFoldersBeforeAnyWindowOpens() throws {
        let store = try container()
        let context = store.mainContext
        let inbox = try TakeNoteIntentStore.inbox(in: context)
        let starred = try TakeNoteIntentStore.starred(in: context)
        #expect(inbox.isInbox && !inbox.canBeDeleted)
        #expect(starred.isStarred && !starred.canBeDeleted)
        #expect(try TakeNoteIntentStore.inbox(in: context) === inbox)
        #expect(try TakeNoteIntentStore.starred(in: context) === starred)
        #expect(try context.fetchCount(FetchDescriptor<NoteContainer>()) == 2)
    }

    @Test func missingContainerDoesNotResolveByDisplayName() throws {
        let store = try container()
        let folder = NoteContainer(name: "Work")
        store.mainContext.insert(folder)
        try store.mainContext.save()
        let invalid = NoteFolderEntity(id: "folder:invalid", name: "Work", symbol: "folder", isSystemFolder: false)
        #expect(throws: TakeNoteIntentError.self) {
            try TakeNoteIntentStore.folder(for: invalid, in: store.mainContext)
        }
    }

    @Test func spotlightDelegateExcludesHiddenNotes() async throws {
        let store = try container()
        let inbox = NoteContainer(isInbox: true, name: "Inbox")
        let archive = NoteContainer(name: "Archive")
        archive.isArchive = true
        let trash = NoteContainer(isTrash: true, name: "Trash")
        let buffer = NoteContainer(name: "Buffer")
        buffer.isBuffer = true
        let folders = [inbox, archive, trash, buffer]
        folders.forEach { store.mainContext.insert($0) }
        let notes = folders.map { Note(folder: $0) }
        notes.forEach { store.mainContext.insert($0) }
        try store.mainContext.save()
        let delegate = NoteSpotlightDelegate(modelContainer: store)
        let items = await delegate.searchableItems(forIdentifiers: notes.map { $0.uuid.uuidString })
        #expect(items.map(\.uniqueIdentifier) == [notes[0].uuid.uuidString])
        let missing = await delegate.searchableItems(forIdentifiers: [UUID().uuidString, "invalid"])
        #expect(missing.isEmpty)
    }

    @Test func editsAndDeletesDuringRebuildAreSerialized() async {
        let index = RecordingIndex()
        index.holdReset = true
        let service = SearchIndexService(spotlight: index)
        let first = Note(folder: NoteContainer(name: "Inbox"))
        first.content = "old"
        let second = Note(folder: NoteContainer(name: "Inbox"))
        service.reindexAll([first, second])
        await index.waitForReset()
        first.content = "new"
        service.reindex(note: first)
        service.deleteFromIndex(noteID: second.uuid)
        index.releaseReset()
        await service.waitForPendingIndexing()
        #expect(index.notes[first.uuid]?.content == "new")
        #expect(index.notes[second.uuid] == nil)
        #expect(!index.overlappedReset)
    }

    @Test func emptyRebuildRemovesStaleNotes() async {
        let index = RecordingIndex()
        let note = Note(folder: NoteContainer(name: "Inbox"))
        index.notes[note.uuid] = NoteSearchEntity(note: note)
        let service = SearchIndexService(spotlight: index)
        service.reindexAll([])
        await service.waitForPendingIndexing()
        #expect(index.notes.isEmpty)
    }

    @Test func restoredNoteWinsOverPendingDeletion() async {
        let index = RecordingIndex()
        let service = SearchIndexService(spotlight: index)
        let note = Note(folder: NoteContainer(name: "Inbox"))
        service.deleteFromIndex(noteID: note.uuid)
        service.reindex(note: note)
        await service.waitForPendingIndexing()
        #expect(index.notes[note.uuid] != nil)
    }

    @Test func archiveCannotBeReindexedAndSearchWaitsForEdits() async {
        let index = RecordingIndex()
        let service = SearchIndexService(spotlight: index)
        let note = Note(folder: NoteContainer(name: "Inbox"))
        note.content = "fresh content"
        service.reindex(note: note)
        let hits = await service.search("fresh")
        #expect(hits.map(\.noteID) == [note.uuid])
        let archive = NoteContainer(name: "Archive")
        archive.isArchive = true
        note.folder = archive
        service.reindex(note: note)
        await service.waitForPendingIndexing()
        #expect(index.notes[note.uuid] == nil)
    }
}

@MainActor
private final class RecordingIndex: NoteSearchIndex {
    var notes: [UUID: NoteSearchEntity] = [:]
    var holdReset = false
    var overlappedReset = false
    private var resetIsRunning = false
    private var resetStarted: CheckedContinuation<Void, Never>?
    private var resetGate: CheckedContinuation<Void, Never>?

    func waitForReset() async {
        if resetIsRunning { return }
        await withCheckedContinuation { resetStarted = $0 }
    }

    func releaseReset() {
        resetGate?.resume()
        resetGate = nil
    }

    func reindex(_ entities: [NoteSearchEntity]) async {
        overlappedReset = overlappedReset || resetIsRunning
        for entity in entities { notes[entity.id] = entity }
    }

    func delete(noteIDs: [UUID]) async {
        overlappedReset = overlappedReset || resetIsRunning
        for id in noteIDs { notes[id] = nil }
    }

    func deleteAll() async {
        resetIsRunning = true
        if holdReset {
            await withCheckedContinuation { continuation in
                resetGate = continuation
                resetStarted?.resume()
                resetStarted = nil
            }
        }
        notes.removeAll()
        resetIsRunning = false
    }

    func search(_ text: String, limit: Int) async -> [SearchHit] {
        Array(notes.values.filter { $0.content.contains(text) }.prefix(limit)).map {
            SearchHit(id: $0.id.uuidString, noteID: $0.id, noteTitle: $0.title, chunk: $0.content)
        }
    }
}
