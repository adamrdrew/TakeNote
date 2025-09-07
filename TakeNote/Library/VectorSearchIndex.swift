//
//  VectorSearchIndex.swift
//  TakeNote
//
//  Created by Adam Drew on 9/6/25.
//

import Foundation
import NaturalLanguage
import os

// MARK: - Public API-compatible adapter

final class VectorSearchIndex {
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "VectorSearchIndex")
    private let chunker: WindowChunker
    private let embedder: EmbeddingProvider

    // In-memory store of embedded chunks (swap to SwiftData/ObjectBox later)
    private var chunks: [ChunkRecord] = []
    private var nextRowID: Int64 = 1

    // Internal chunk record
    private struct ChunkRecord {
        let id: Int64
        let noteID: UUID
        let text: String
        let vector: [Float] // L2-normalized
        let updatedAt: Date
    }

    // MARK: Init
    init(inMemory: Bool = true) {
        self.chunker = WindowChunker()
        self.embedder = EmbeddingProvider()
    }

    // MARK: Indexing

    /// Index 1 note (replace all its chunks)
    func reindex(noteID: UUID, markdown: String) {
        delete(noteID: noteID)
        let newChunks = makeChunks(noteID: noteID, markdown: markdown)
        chunks.append(contentsOf: newChunks)
        logger.debug("Reindexed note \(noteID, privacy: .public) with \(newChunks.count) chunk(s)")
    }

    /// Index many notes (replace each note's chunks)
    func reindex(_ notes: [(UUID, String)]) {
        let ids = Set(notes.map { $0.0 })
        chunks.removeAll { ids.contains($0.noteID) }
        var added = 0
        for (id, md) in notes {
            let cs = makeChunks(noteID: id, markdown: md)
            chunks.append(contentsOf: cs)
            added += cs.count
        }
        logger.debug("Bulk reindex completed. Notes: \(notes.count), Chunks added: \(added)")
    }

    /// Destroy entire in-memory index
    func dropAll() {
        chunks.removeAll()
        nextRowID = 1
        logger.debug("VectorSearchIndex dropAll(): cleared in-memory index")
    }

    /// Remove a single note’s chunks
    func delete(noteID: UUID) {
        let before = chunks.count
        chunks.removeAll { $0.noteID == noteID }
        let removed = before - chunks.count
        if removed > 0 {
            logger.debug("Deleted \(removed) chunk(s) for note \(noteID, privacy: .public)")
        }
    }

    // MARK: Search

    /// Back-compat alias
    func searchNatural(_ text: String, limit: Int = 5) -> [SearchHit] {
        return search(text, limit: limit)
    }

    /// Dense (cosine) search over embedded chunks with light anchor scoping
    func search(_ query: String, limit: Int = 5) -> [SearchHit] {
        guard !chunks.isEmpty else { return [] }

        let candidates = chunks

        // 2) Embed the query once (sentence embedding)
        guard let qvec = embedder.embed(query) else { return [] }

        // 3) Cosine = dot product (vectors are unit-normalized)
        // Use a tiny fixed-size min-heap pattern to avoid sorting all scores
        let k = max(limit, 1)
        var heap: [(score: Float, idx: Int)] = [] // min-heap (score asc)

        func push(_ item: (Float, Int)) {
            heap.append(item)
            heap.sort { $0.score < $1.score } // small k: this is fine & simple
            if heap.count > k { _ = heap.removeFirst() }
        }

        for (i, c) in candidates.enumerated() {
            let s = dot(qvec, c.vector)
            push((s, i))
        }

        // 4) Highest scores last in heap; return in descending score order
        let top = heap.sorted { $0.score > $1.score }
        return top.map { hit in
            let rec = candidates[hit.idx]
            return SearchHit(id: rec.id, noteID: rec.noteID, chunk: rec.text)
        }
    }

    // MARK: - Helpers

    private func makeChunks(noteID: UUID, markdown: String) -> [ChunkRecord] {
        // NOTE: your current WindowChunker has no overlap; keep as-is for now.
        // If you add overlap later, this method doesn’t change.
        let parts = chunker.chunks(for: markdown)
        var out: [ChunkRecord] = []
        out.reserveCapacity(parts.count)

        for p in parts {
            guard let vec = embedder.embed(p.text) else { continue }
            out.append(.init(
                id: nextRowID,
                noteID: noteID,
                text: p.text,
                vector: vec,
                updatedAt: Date()
            ))
            nextRowID &+= 1
        }
        return out
    }

    @inline(__always)
    private func dot(_ a: [Float], _ b: [Float]) -> Float {
        // Preconditions should hold: equal length, both unit vectors
        var s: Float = 0
        for i in 0..<min(a.count, b.count) { s += a[i] * b[i] }
        return s
    }
}
