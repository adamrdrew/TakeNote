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
