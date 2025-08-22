//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

@MainActor
@Observable
internal final class SearchIndexService {
    #if DEBUG
    let index = try! SearchIndex(inMemory: true)
    #else
    let index = try! SearchIndex()
    #endif
    
    var hits: [SearchIndex.SearchHit] = []
    var isIndexing: Bool = false

    func reindex(note: Note) {
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    func reindexAll(_ notes: [Note]) {
        isIndexing = true
        Task {
            index.reindex(notes.map { ($0.uuid, $0.content) })
            isIndexing = false
        }
    }
    
    func dropAll() {
        Task { index.dropAll() }
    }
    
}
