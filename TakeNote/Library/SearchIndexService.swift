//
//  SearchIndexService.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

@MainActor
final class SearchIndexService: ObservableObject {
    let index = try! SearchIndex(inMemory: true)   // uses WindowChunker(maxChars: 1000)
    @Published var hits: [SearchIndex.SearchHit] = []

    func reindex(note: Note) {
        Task { index.reindex(noteID: note.uuid, markdown: note.content) }
    }

    func reindexAll(_ notes: [Note]) {
        Task { index.reindex(notes.map { ($0.uuid, $0.content) }) }
    }

    func search(_ q: String) {
        Task { [weak self] in
            guard let self else { return }
            let r = self.index.search(q, limit: 50)
            self.hits = r     // already explicit
        }
    }
    
    

}
