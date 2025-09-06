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
    let index = VectorSearchIndex(inMemory: true)
    #else
    let index = VectorSearchIndex()
    #endif
    
    // Explicitly use the top-level SearchHit type to avoid the macro qualifying it as SearchIndex.SearchHit
    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    var lastReindexAllDate: Date = .distantPast
    var logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")

    var chatFeatureFlagEnabled : Bool {
        return Bundle.main.object(forInfoDictionaryKey: "MagicChatenabled") as? Bool ?? false
    }
    
    func canReindexAllNotes() -> Bool {
        if isIndexing { return false }
        return Date().timeIntervalSince(lastReindexAllDate) >= 10 * 60
    }
    
    func reindex(note: Note) {
        if !chatFeatureFlagEnabled { return }
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    func reindexAll(_ noteData: [(UUID, String)]) {
        if !chatFeatureFlagEnabled { return }
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
        if !chatFeatureFlagEnabled { return }
        Task { index.dropAll() }
    }
    
}
