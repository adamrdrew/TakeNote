//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

@MainActor
final class SearchIndexService: ObservableObject {
    #if DEBUG
    let index = try! SearchIndex(inMemory: true)
    #else
    let index = try! SearchIndex()
    #endif
    
    @Published var hits: [SearchIndex.SearchHit] = []
    @Published var isIndexing: Bool = false

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

    func search(_ q: String) {
        Task { [weak self] in
            guard let self else { return }
            let r = self.index.searchNatural(q, limit: 3)
            self.hits = r     // already explicit
        }
    }
    
}
