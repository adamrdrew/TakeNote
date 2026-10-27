//
//  NoteSpotlightDelegate.swift
//  TakeNote
//

import CoreSpotlight
import os
import SwiftData

nonisolated final class NoteSpotlightDelegate: NSObject, CSSearchableIndexDelegate, @unchecked Sendable {
    // Core Spotlight supplies this legacy callback for invocation after async
    // indexing, on any queue, but does not annotate it as @Sendable.
    private struct Acknowledgement: @unchecked Sendable {
        let handler: () -> Void
        func callAsFunction() { handler() }
    }
    // The immutable container is Sendable; each synchronous fetch owns its own
    // ModelContext and never carries a live model across a suspension.
    private let modelContainer: ModelContainer
    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteSpotlightDelegate"
    )

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func searchableIndex(
        _ searchableIndex: CSSearchableIndex,
        reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void
    ) {
        reindexSearchableItems(on: searchableIndex, acknowledgementHandler: acknowledgementHandler)
    }

    nonisolated func searchableIndex(
        _ searchableIndex: CSSearchableIndex,
        reindexSearchableItemsWithIdentifiers identifiers: [String],
        acknowledgementHandler: @escaping () -> Void
    ) {
        reindexSearchableItems(
            on: searchableIndex,
            matching: noteIDs(from: identifiers),
            acknowledgementHandler: acknowledgementHandler
        )
    }

    nonisolated func searchableItems(forIdentifiers identifiers: [String]) async -> [CSSearchableItem] {
        searchableItems(matching: noteIDs(from: identifiers))
    }

    nonisolated func searchableItems(
        forIdentifiers identifiers: [String],
        protectionClass: FileProtectionType
    ) async -> [CSSearchableItem] {
        searchableItems(matching: noteIDs(from: identifiers))
    }

    private func reindexSearchableItems(
        on searchableIndex: CSSearchableIndex,
        matching noteIDs: Set<UUID>? = nil,
        acknowledgementHandler: @escaping () -> Void
    ) {
        let items = searchableItems(matching: noteIDs)
        guard !items.isEmpty else {
            acknowledgementHandler()
            return
        }
        let acknowledge = Acknowledgement(handler: acknowledgementHandler)
        searchableIndex.indexSearchableItems(items) { [logger] error in
            if let error {
                logger.error("Spotlight delegate reindex failed: \(error.localizedDescription)")
            }
            acknowledge()
        }
    }

    private func searchableItems(matching noteIDs: Set<UUID>? = nil) -> [CSSearchableItem] {
        do {
            let context = ModelContext(modelContainer)
            let notes = try context.fetch(
                FetchDescriptor<Note>(
                    sortBy: [SortDescriptor(\.updatedDate, order: .reverse)]
                )
            )
            return notes
                .filter { note in
                    SearchIndexService.isIndexable(note) && (noteIDs?.contains(note.uuid) ?? true)
                }
                .map { NoteSearchEntity(note: $0).searchableItem }
        } catch {
            logger.error("Spotlight delegate fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    nonisolated private func noteIDs(from identifiers: [String]) -> Set<UUID> {
        Set(identifiers.compactMap(UUID.init(uuidString:)))
    }

}
