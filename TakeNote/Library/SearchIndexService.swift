//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI
import os

@MainActor
@Observable
class SearchIndexService {
    #if DEBUG
    let index = try! SearchIndex(inMemory: true)
    #else
    let index = try! SearchIndex()
    #endif
    
    var hits: [SearchIndex.SearchHit] = []
    var isIndexing: Bool = false
    var lastReindexAllDate: Date = .distantPast
    var logger = Logger(subsystem: "com.adammdrew.takenote", category: "SearchIndexService")

    func canReindexAllNotes() -> Bool {
        if isIndexing { return false }
        return Date().timeIntervalSince(lastReindexAllDate) >= 10 * 60
    }
    
    func reindex(note: Note) {
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    func reindexAll(_ noteData: [(UUID, String)]) {
        if !canReindexAllNotes() { return }
        logger.info("RAG search reindex running.")
        lastReindexAllDate = Date()
        isIndexing = true
        Task {
            index.reindex(noteData)
            isIndexing = false
        }
    }
    
    func dropAll() {
        Task { index.dropAll() }
    }
    
}
