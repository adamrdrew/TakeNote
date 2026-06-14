//
//  NoteSpotlightIndex.swift
//  TakeNote
//

import AppIntents
import CoreSpotlight
import os

final class NoteSpotlightIndex: Sendable {
    static let domainIdentifier = "com.adamdrew.takenote.notes"

    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteSpotlightIndex"
    )

    func reindex(_ note: NoteSearchEntity) async {
        await reindex([note])
    }

    func reindex(_ notes: [NoteSearchEntity]) async {
        guard CSSearchableIndex.isIndexingAvailable(), !notes.isEmpty else {
            return
        }

        let items = notes.map { note in
            let item = CSSearchableItem(
                uniqueIdentifier: note.id.uuidString,
                domainIdentifier: Self.domainIdentifier,
                attributeSet: note.attributeSet
            )
            item.expirationDate = .distantFuture
            item.associateAppEntity(note)
            return item
        }

        do {
            try await indexSearchableItems(items)
            logger.debug("Indexed \(notes.count) notes in Spotlight.")
        } catch {
            logger.error("Spotlight indexing error: \(error.localizedDescription)")
        }
    }

    func delete(noteID: UUID) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        do {
            try await deleteSearchableItems(withIdentifiers: [noteID.uuidString])
            logger.debug("Deleted note \(noteID.uuidString) from Spotlight.")
        } catch {
            logger.error("Spotlight delete error: \(error.localizedDescription)")
        }
    }

    func deleteAll() async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        do {
            try await deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
            logger.debug("Deleted all TakeNote notes from Spotlight.")
        } catch {
            logger.error("Spotlight delete all error: \(error.localizedDescription)")
        }
    }

    func search(_ text: String, limit: Int) async -> [SearchHit] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CSSearchableIndex.isIndexingAvailable(), !trimmed.isEmpty else {
            return []
        }

        let context = CSUserQueryContext()
        context.enableRankedResults = true
        context.maxResultCount = limit
        context.maxRankedResultCount = limit
        context.fetchAttributes = [
            SearchableItemAttribute.title.rawValue,
            SearchableItemAttribute.textContent.rawValue,
            SearchableItemAttribute.contentDescription.rawValue,
            SearchableItemAttribute.identifier.rawValue,
            SearchableItemAttribute.domainIdentifier.rawValue
        ]
        context.filterQueries = [
            "\(SearchableItemAttribute.domainIdentifier.rawValue) == \"\(Self.domainIdentifier)\""
        ]

        let query = CSUserQuery(userQueryString: trimmed, userQueryContext: context)
        var hits: [SearchHit] = []

        do {
            for try await response in query.responses {
                guard case .item(let result) = response else { continue }
                let item = result.item
                guard item.domainIdentifier == Self.domainIdentifier else { continue }
                guard let noteID = UUID(uuidString: item.uniqueIdentifier) else { continue }

                let attributes = item.attributeSet
                let chunk = attributes.textContent
                    ?? attributes.contentDescription
                    ?? attributes.title
                    ?? ""

                hits.append(
                    SearchHit(
                        id: item.uniqueIdentifier,
                        noteID: noteID,
                        chunk: chunk
                    )
                )

                if hits.count >= limit {
                    query.cancel()
                    break
                }
            }
        } catch {
            logger.error("Spotlight search error: \(error.localizedDescription)")
        }

        return hits
    }

    private func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteSearchableItems(withDomainIdentifiers identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
