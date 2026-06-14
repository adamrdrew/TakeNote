//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI
import os

// MARK: Result type
struct SearchHit: Identifiable, Hashable {
    let id: Int64  // rowid inside FTS table
    let noteID: UUID
    let chunk: String  // the stored chunk text
}

@MainActor
@Observable
class SearchIndexService {
    #if DEBUG
    let index = try! SearchIndex(inMemory: true)
    #else
    let index = try! SearchIndex()
    #endif
    private let spotlight = NoteSpotlightIndex()

    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    var logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")
    private var reindexTask: Task<Void, Never>?

    func reindex(note: Note) {
        let entity = NoteSearchEntity(note: note)
        Task {
            index.reindex(noteID: entity.id, markdown: entity.content)
            await spotlight.reindex(entity)
        }
    }

    func reindexAll(_ noteData: [(UUID, String)]) {
        reindexTask?.cancel()
        logger.info("FTS search reindex running.")
        isIndexing = true
        reindexTask = Task {
            index.reindex(noteData)
            if Task.isCancelled {
                isIndexing = false
                return
            }
            isIndexing = false
            #if DEBUG
            logger.info("FTS search reindex complete. \(noteData.count) notes indexed, \(self.index.rowCount) chunks in index.")
            #endif
        }
    }

    func reindexAll(_ notes: [Note]) {
        let noteData = notes.map { ($0.uuid, $0.content) }
        let spotlightEntities = notes.map(NoteSearchEntity.init(note:))

        reindexTask?.cancel()
        logger.info("FTS and Spotlight search reindex running.")
        isIndexing = true
        reindexTask = Task {
            index.reindex(noteData)
            if Task.isCancelled {
                isIndexing = false
                return
            }
            await spotlight.reindex(spotlightEntities)
            if Task.isCancelled {
                isIndexing = false
                return
            }
            isIndexing = false
            #if DEBUG
            logger.info("Search reindex complete. \(noteData.count) notes indexed, \(self.index.rowCount) chunks in FTS index.")
            #endif
        }
    }

    func deleteFromIndex(noteID: UUID) {
        logger.debug("Removing note \(noteID) from FTS index.")
        Task {
            index.delete(noteID: noteID)
            await spotlight.delete(noteID: noteID)
        }
    }

    func deleteAllFromIndex() {
        logger.debug("Removing all notes from search indexes.")
        Task {
            index.deleteAll()
            await spotlight.deleteAll()
        }
    }

    func searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID] {
        index.searchNoteIDs(text, limit: limit)
    }

}
