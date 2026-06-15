//
//  TakeNoteIntentEntities.swift
//  TakeNote
//

import AppIntents
import Foundation
import SwiftData

enum TakeNoteIntentError: LocalizedError, Sendable {
    case noteNotFound
    case folderNotFound
    case tagNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noteNotFound:
            String(
                localized: "TakeNote could not find that note.",
                comment: "App Intent error shown when a selected note no longer exists."
            )
        case .folderNotFound:
            String(
                localized: "TakeNote could not find that folder.",
                comment: "App Intent error shown when a selected folder no longer exists."
            )
        case .tagNotFound:
            String(
                localized: "TakeNote could not find that tag.",
                comment: "App Intent error shown when a selected tag no longer exists."
            )
        case .saveFailed:
            String(
                localized: "TakeNote could not save your changes.",
                comment: "App Intent error shown when SwiftData could not save changes."
            )
        }
    }
}

struct NoteFolderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Folder")
    }

    static let defaultQuery = NoteFolderEntityQuery()

    let id: String
    let name: String
    let symbol: String
    let isSystemFolder: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: DisplayRepresentation.Image(systemName: symbol)
        )
    }

    init(id: String, name: String, symbol: String, isSystemFolder: Bool) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.isSystemFolder = isSystemFolder
    }

    init(container: NoteContainer) {
        self.init(
            id: Self.identifier(for: container),
            name: container.name,
            symbol: container.symbol,
            isSystemFolder: container.isSystemFolder
        )
    }

    static func identifier(for container: NoteContainer) -> String {
        "folder:\(container.name)"
    }
}

struct NoteFolderEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @MainActor
    func entities(for identifiers: [String]) async throws -> [NoteFolderEntity] {
        let identifierSet = Set(identifiers)
        return try fetchFolders().filter { identifierSet.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteFolderEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return try fetchFolders().filter {
            $0.name.localizedStandardContains(query)
        }
    }

    @MainActor
    func allEntities() async throws -> [NoteFolderEntity] {
        try fetchFolders()
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteFolderEntity] {
        try Array(fetchFolders().prefix(20))
    }

    @MainActor
    private func fetchFolders() throws -> [NoteFolderEntity] {
        let context = ModelContext(modelContainer)
        let folders = try context.fetch(
            FetchDescriptor<NoteContainer>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
        return folders
            .filter {
                !$0.isTag && !$0.isTrash && !$0.isBuffer
                    && !$0.isAllNotes && !$0.isStarred
            }
            .map(NoteFolderEntity.init(container:))
    }
}

struct NoteTagEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Tag")
    }

    static let defaultQuery = NoteTagEntityQuery()

    let id: String
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: DisplayRepresentation.Image(systemName: symbol)
        )
    }

    init(id: String, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    init(container: NoteContainer) {
        self.init(
            id: Self.identifier(for: container),
            name: container.name,
            symbol: container.symbol
        )
    }

    static func identifier(for container: NoteContainer) -> String {
        "tag:\(container.name)"
    }
}

struct NoteTagEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    @MainActor
    func entities(for identifiers: [String]) async throws -> [NoteTagEntity] {
        let identifierSet = Set(identifiers)
        return try fetchTags().filter { identifierSet.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteTagEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return try fetchTags().filter {
            $0.name.localizedStandardContains(query)
        }
    }

    @MainActor
    func allEntities() async throws -> [NoteTagEntity] {
        try fetchTags()
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteTagEntity] {
        try Array(fetchTags().prefix(20))
    }

    @MainActor
    private func fetchTags() throws -> [NoteTagEntity] {
        let context = ModelContext(modelContainer)
        let tags = try context.fetch(
            FetchDescriptor<NoteContainer>(
                predicate: #Predicate { $0.isTag },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
        return tags.map(NoteTagEntity.init(container:))
    }
}

@MainActor
enum TakeNoteIntentStore {
    static func note(
        for entity: NoteSearchEntity,
        in context: ModelContext
    ) throws -> Note {
        let noteID = entity.id
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.uuid == noteID }
        )
        guard let note = try context.fetch(descriptor).first else {
            throw TakeNoteIntentError.noteNotFound
        }
        return note
    }

    static func folder(
        for entity: NoteFolderEntity,
        in context: ModelContext
    ) throws -> NoteContainer {
        let name = entity.name
        let descriptor = FetchDescriptor<NoteContainer>(
            predicate: #Predicate {
                !$0.isTag && $0.name == name
            }
        )
        guard let folder = try context.fetch(descriptor).first else {
            throw TakeNoteIntentError.folderNotFound
        }
        return folder
    }

    static func tag(
        for entity: NoteTagEntity,
        in context: ModelContext
    ) throws -> NoteContainer {
        let name = entity.name
        let descriptor = FetchDescriptor<NoteContainer>(
            predicate: #Predicate {
                $0.isTag && $0.name == name
            }
        )
        guard let tag = try context.fetch(descriptor).first else {
            throw TakeNoteIntentError.tagNotFound
        }
        return tag
    }

    static func inbox(in context: ModelContext) throws -> NoteContainer {
        if let inbox = try fetchContainer(
            in: context,
            predicate: #Predicate<NoteContainer> { $0.isInbox }
        ) {
            return inbox
        }
        let inbox = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: true,
            isStarred: false,
            name: TakeNoteVM.inboxFolderName,
            symbol: "tray",
            isTag: false
        )
        context.insert(inbox)
        try save(context)
        return inbox
    }

    static func trash(in context: ModelContext) throws -> NoteContainer {
        if let trash = try fetchContainer(
            in: context,
            predicate: #Predicate<NoteContainer> { $0.isTrash }
        ) {
            return trash
        }
        let trash = NoteContainer(
            canBeDeleted: false,
            isTrash: true,
            isInbox: false,
            isStarred: false,
            name: TakeNoteVM.trashFolderName,
            symbol: "trash",
            isTag: false
        )
        context.insert(trash)
        try save(context)
        return trash
    }

    static func archive(in context: ModelContext) throws -> NoteContainer {
        if let archive = try fetchContainer(
            in: context,
            predicate: #Predicate<NoteContainer> { $0.isArchive }
        ) {
            return archive
        }
        let archive = NoteContainer(
            canBeDeleted: false,
            isTrash: false,
            isInbox: false,
            isStarred: false,
            name: TakeNoteVM.archiveFolderName,
            symbol: "archivebox",
            isTag: false
        )
        archive.isArchive = true
        context.insert(archive)
        try save(context)
        return archive
    }

    private static func fetchContainer(
        in context: ModelContext,
        predicate: Predicate<NoteContainer>
    ) throws -> NoteContainer? {
        let descriptor = FetchDescriptor<NoteContainer>(
            predicate: predicate
        )
        return try context.fetch(descriptor).first
    }

    static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw TakeNoteIntentError.saveFailed
        }
    }
}
