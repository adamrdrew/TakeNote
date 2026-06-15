//
//  TakeNoteContainerIntents.swift
//  TakeNote
//

import AppIntents
import SwiftData

struct CreateFolderIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @Parameter(title: "Name")
    var name: String

    static let title: LocalizedStringResource = "Create Folder"
    static let description = IntentDescription("Create a folder in TakeNote.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteFolderEntity> {
        let context = modelContainer.mainContext
        let folder = NoteContainer(
            canBeDeleted: true,
            isTrash: false,
            isInbox: false,
            name: name
        )
        context.insert(folder)
        try TakeNoteIntentStore.save(context)
        return .result(value: NoteFolderEntity(container: folder))
    }
}

struct CreateTagIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @Parameter(title: "Name")
    var name: String

    static let title: LocalizedStringResource = "Create Tag"
    static let description = IntentDescription("Create a tag in TakeNote.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteTagEntity> {
        let context = modelContainer.mainContext
        let tag = NoteContainer(
            isTrash: false,
            isInbox: false,
            name: name,
            symbol: "tag.fill",
            isTag: true
        )
        context.insert(tag)
        try TakeNoteIntentStore.save(context)
        return .result(value: NoteTagEntity(container: tag))
    }
}

struct RenameFolderIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @Parameter(title: "Folder")
    var folder: NoteFolderEntity
    @Parameter(title: "Name")
    var name: String

    static let title: LocalizedStringResource = "Rename Folder"
    static let description = IntentDescription("Rename a TakeNote folder.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteFolderEntity> {
        let context = modelContainer.mainContext
        let folder = try TakeNoteIntentStore.folder(for: folder, in: context)
        folder.name = name
        try TakeNoteIntentStore.save(context)
        return .result(value: NoteFolderEntity(container: folder))
    }
}

struct RenameTagIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @Parameter(title: "Tag")
    var tag: NoteTagEntity
    @Parameter(title: "Name")
    var name: String

    static let title: LocalizedStringResource = "Rename Tag"
    static let description = IntentDescription("Rename a TakeNote tag.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteTagEntity> {
        let context = modelContainer.mainContext
        let tag = try TakeNoteIntentStore.tag(for: tag, in: context)
        tag.name = name
        try TakeNoteIntentStore.save(context)
        return .result(value: NoteTagEntity(container: tag))
    }
}

struct DeleteFolderIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Folder")
    var folder: NoteFolderEntity

    static let title: LocalizedStringResource = "Delete Folder"
    static let description = IntentDescription("Move a TakeNote folder's notes to Trash and delete the folder.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let folder = try TakeNoteIntentStore.folder(for: folder, in: context)
        let trash = try TakeNoteIntentStore.trash(in: context)
        for note in folder.notes {
            note.folder = trash
            note.starred = false
            note.starredFolder = nil
            search.deleteFromIndex(noteID: note.uuid)
        }
        context.delete(folder)
        try TakeNoteIntentStore.save(context)
        return .result()
    }
}

struct DeleteTagIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    @Parameter(title: "Tag")
    var tag: NoteTagEntity

    static let title: LocalizedStringResource = "Delete Tag"
    static let description = IntentDescription("Delete a TakeNote tag.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let tag = try TakeNoteIntentStore.tag(for: tag, in: context)
        let notes = tag.notes
        for note in notes where note.tag == tag {
            note.tag = nil
            search.reindex(note: note)
        }
        context.delete(tag)
        try TakeNoteIntentStore.save(context)
        return .result()
    }
}

struct EmptyTrashIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "SearchIndexService")
    private var search: SearchIndexService

    static let title: LocalizedStringResource = "Empty Trash"
    static let description = IntentDescription("Permanently delete all notes in TakeNote Trash.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let trash = try TakeNoteIntentStore.trash(in: context)
        for note in trash.notes {
            search.deleteFromIndex(noteID: note.uuid)
            context.delete(note)
        }
        try TakeNoteIntentStore.save(context)
        NoteImageManager(modelContext: context).cullOrphanedImages()
        return .result()
    }
}
