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

    func canReindexAllNotes() -> Bool {
        if isIndexing { return false }
        return Date().timeIntervalSince(lastReindexAllDate) >= 10 * 60
    }

    func reindex(note: Note) {
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    func reindexAll(_ noteData: [(UUID, String)]) {
        if !canReindexAllNotes() { return }
        logger.info("FTS search reindex running.")
        lastReindexAllDate = Date()
        isIndexing = true
        Task {
            index.reindex(noteData)
            isIndexing = false
            #if DEBUG
            logger.info("FTS search reindex complete. \(noteData.count) notes indexed, \(self.index.rowCount) chunks in index.")
            #endif
        }
    }

    func dropAll() {
        Task { index.dropAll() }
    }

    func deleteFromIndex(noteID: UUID) {
        logger.debug("Removing note \(noteID) from FTS index.")
        Task { index.delete(noteID: noteID) }
    }

    func searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID] {
        index.searchNoteIDs(text, limit: limit)
    }

}
