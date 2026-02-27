//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI
import os

// MARK: Result type
struct SearchHit: Identifiable {
    public let id: Int64  // rowid inside FTS table
    public let noteID: UUID
    public let chunk: String  // the stored chunk text
}

@MainActor
@Observable
class SearchIndexService {
    #if DEBUG
    let index = try! SearchIndex(inMemory: true)
    #else
    let index = try! SearchIndex()
    #endif
    
    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    var lastReindexAllDate: Date = .distantPast
    var logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")

    // Intentional L07 deviation: the FTS5 index now serves dual purpose (chat RAG and
    // keyword search) and is unconditionally maintained regardless of chatFeatureFlagEnabled.
    // Chat UI surfaces remain gated on chatFeatureFlagEnabled; only the indexing gate is removed.
    func canReindexAllNotes() -> Bool {
        if isIndexing { return false }
        return Date().timeIntervalSince(lastReindexAllDate) >= 10 * 60
    }

    // Intentional L07 deviation: index is maintained unconditionally (see above).
    func reindex(note: Note) {
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    // Intentional L07 deviation: index is maintained unconditionally (see above).
    func reindexAll(_ noteData: [(UUID, String)]) {
        if !canReindexAllNotes() { return }
        logger.info("RAG search reindex running.")
        lastReindexAllDate = Date()
        isIndexing = true
        Task {
            index.reindex(noteData)
            isIndexing = false
            #if DEBUG
            logger.info("RAG search reindex complete. \(noteData.count) notes indexed, \(self.index.rowCount) chunks in index.")
            #endif
        }
    }

    // Intentional L07 deviation: index is maintained unconditionally (see above).
    func dropAll() {
        Task { index.dropAll() }
    }

    // Intentional L07 deviation: index is maintained unconditionally (see above).
    func deleteFromIndex(noteID: UUID) {
        logger.debug("Removing note \(noteID) from FTS index.")
        Task { index.delete(noteID: noteID) }
    }

}
