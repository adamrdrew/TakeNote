//
//  TakeNoteNoteIntents.swift
//  TakeNote
//

import AppIntents
import SwiftData

struct FindNotesIntent: AppIntent {
    @Parameter(title: "Search Text")
    var searchText: String

    static let title: LocalizedStringResource = "Find Notes"
    static let description = IntentDescription("Find notes in TakeNote by title, content, folder, or tag.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteSearchEntity]> {
        let results = try await NoteSearchEntity.defaultQuery.entities(
            matching: searchText
        )
        return .result(value: results)
    }
}

struct OpenNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM")
    private var takeNoteVM: TakeNoteVM

    @Parameter(title: "Note")
    var note: NoteSearchEntity

    static let title: LocalizedStringResource = "Open Note"
    static let description = IntentDescription("Open a note in TakeNote.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        takeNoteVM.selectedContainer = note.folder
        takeNoteVM.selectedNotes = [note]
        takeNoteVM.openNote = note
        return .result()
    }
}

struct UpdateNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity
    @Parameter(title: "Title")
    var title: String?
    @Parameter(title: "Content")
    var content: String?

    static let title: LocalizedStringResource = "Update Note"
    static let description = IntentDescription("Update a TakeNote note's title, content, or both.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)

        if let title {
            note.setTitle(title)
        }
        if let content {
            note.setContent(content)
        }
        try TakeNoteIntentStore.save(context)
        search.reindex(note: note)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct AppendToNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity
    @Parameter(title: "Text")
    var text: String

    static let title: LocalizedStringResource = "Append to Note"
    static let description = IntentDescription("Append text to an existing TakeNote note.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        let separator = note.content.isEmpty ? "" : "\n\n"
        note.setContent("\(note.content)\(separator)\(text)")
        try TakeNoteIntentStore.save(context)
        search.reindex(note: note)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct MoveNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity
    @Parameter(title: "Folder")
    var folder: NoteFolderEntity

    static let title: LocalizedStringResource = "Move Note"
    static let description = IntentDescription("Move a TakeNote note to a folder.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        let folder = try TakeNoteIntentStore.folder(for: folder, in: context)
        note.setFolder(folder)
        try TakeNoteIntentStore.save(context)
        if folder.isArchive {
            search.deleteFromIndex(noteID: note.uuid)
        } else {
            search.reindex(note: note)
        }
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct SetNoteTagIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity
    @Parameter(title: "Tag")
    var tag: NoteTagEntity

    static let title: LocalizedStringResource = "Tag Note"
    static let description = IntentDescription("Apply a TakeNote tag to a note.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        let tag = try TakeNoteIntentStore.tag(for: tag, in: context)
        note.setTag(tag)
        try TakeNoteIntentStore.save(context)
        search.reindex(note: note)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct ClearNoteTagIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity

    static let title: LocalizedStringResource = "Clear Note Tag"
    static let description = IntentDescription("Remove the tag from a TakeNote note.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        note.tag = nil
        try TakeNoteIntentStore.save(context)
        search.reindex(note: note)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct SetNoteStarredIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM")
    private var takeNoteVM: TakeNoteVM
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity
    @Parameter(title: "Starred")
    var starred: Bool

    static let title: LocalizedStringResource = "Set Note Starred"
    static let description = IntentDescription("Star or unstar a TakeNote note.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        if note.starred != starred {
            takeNoteVM.noteStarredToggle(note, modelContext: context)
        }
        search.reindex(note: note)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct ArchiveNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity

    static let title: LocalizedStringResource = "Archive Note"
    static let description = IntentDescription("Move a TakeNote note to Archive.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteSearchEntity> {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        let archive = try TakeNoteIntentStore.archive(in: context)
        note.setFolder(archive)
        try TakeNoteIntentStore.save(context)
        search.deleteFromIndex(noteID: note.uuid)
        return .result(value: NoteSearchEntity(note: note))
    }
}

struct TrashNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM")
    private var takeNoteVM: TakeNoteVM
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Note")
    var note: NoteSearchEntity

    static let title: LocalizedStringResource = "Trash Note"
    static let description = IntentDescription("Move a TakeNote note to Trash.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let note = try TakeNoteIntentStore.note(for: note, in: context)
        takeNoteVM.moveNoteToTrash(note, modelContext: context)
        search.deleteFromIndex(noteID: note.uuid)
        return .result()
    }
}
