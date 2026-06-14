//
//  NoteSearchEntity.swift
//  TakeNote
//

import AppIntents
import CoreSpotlight
import SwiftData
import UniformTypeIdentifiers

struct NoteSearchEntity: IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Note")
    }

    static var defaultQuery = NoteSearchEntityQuery()

    let id: UUID
    let title: String
    let content: String
    let folderName: String?
    let createdDate: Date
    let updatedDate: Date
    let isStarred: Bool

    var displayRepresentation: DisplayRepresentation {
        let subtitle = folderName.map { LocalizedStringResource(stringLiteral: $0) }
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: subtitle,
            image: DisplayRepresentation.Image(named: "AppIcon")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = title
        attributes.displayName = title
        attributes.contentDescription = plainTextSummary
        attributes.textContent = plainTextContent
        attributes.keywords = keywords
        attributes.identifier = id.uuidString
        attributes.relatedUniqueIdentifier = id.uuidString
        attributes.metadataModificationDate = updatedDate
        attributes.addedDate = createdDate
        attributes.contentCreationDate = createdDate
        attributes.contentModificationDate = updatedDate
        attributes.userCreated = true
        attributes.userOwned = true
        attributes.rankingHint = isStarred ? 90 : 50
        attributes.domainIdentifier = NoteSpotlightIndex.domainIdentifier
        attributes.containerTitle = folderName
        attributes.containerDisplayName = folderName
        attributes.containerIdentifier = folderName
        attributes.contentURL = URL(string: urlString)
        return attributes
    }

    var urlString: String {
        "takenote://note/\(id.uuidString)"
    }

    private var plainTextContent: String {
        stripMarkdownForSearch(content)
    }

    private var plainTextSummary: String {
        let text = plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 500 else { return text }
        return String(text.prefix(500))
    }

    private var keywords: [String] {
        var values = ["TakeNote", "note", title]
        if let folderName {
            values.append(folderName)
        }
        if isStarred {
            values.append("starred")
        }
        return values
    }

    init(
        id: UUID,
        title: String,
        content: String,
        folderName: String?,
        createdDate: Date,
        updatedDate: Date,
        isStarred: Bool
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.folderName = folderName
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.isStarred = isStarred
    }

    init(note: Note) {
        self.init(
            id: note.uuid,
            title: note.title,
            content: note.content,
            folderName: note.folder?.name,
            createdDate: note.createdDate,
            updatedDate: note.updatedDate,
            isStarred: note.starred
        )
    }
}

struct NoteSearchEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer

    static var findIntentDescription: IntentDescription? {
        IntentDescription("Find notes in TakeNote.")
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [NoteSearchEntity] {
        let identifierSet = Set(identifiers)
        return try fetchSearchableNotes().filter { identifierSet.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteSearchEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }

        let searchableNotes = try fetchSearchableNotes()
        let tokens = query
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { $0.localizedLowercase }

        guard !tokens.isEmpty else { return searchableNotes }

        return searchableNotes.filter { note in
            let haystack = "\(note.title) \(note.content) \(note.folderName ?? "")"
                .localizedLowercase
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    @MainActor
    func allEntities() async throws -> [NoteSearchEntity] {
        try fetchSearchableNotes()
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteSearchEntity] {
        try Array(fetchSearchableNotes().prefix(20))
    }

    @MainActor
    private func fetchSearchableNotes() throws -> [NoteSearchEntity] {
        let context = ModelContext(modelContainer)
        let notes = try context.fetch(
            FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\.updatedDate, order: .reverse)]
            )
        )
        return notes
            .filter { $0.folder?.isTrash != true && $0.folder?.isBuffer != true && $0.folder?.isArchive != true }
            .map(NoteSearchEntity.init(note:))
    }
}
