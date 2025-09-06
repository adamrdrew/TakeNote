//
//  OBSearchIndex.swift
//  TakeNote
//
//  Created by Adam Drew on 9/5/25.
//
import Foundation
import NaturalLanguage
import os
import ObjectBox

func makeStore() -> Store? {
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "OBStoreMaker")

    do {
        // 1) Build a sane on-disk path
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.adamdrew.takenote"
        let directory = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("chunks", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        logger.info("OB dir: \(directory.path, privacy: .public) exists: \(FileManager.default.fileExists(atPath: directory.path)) writable: \(FileManager.default.isWritableFile(atPath: directory.path))")

        // 2) Try on-disk store
        let store = try Store(directoryPath: directory.path)
        logger.info("ObjectBox store opened")
        return store
    } catch {
        logger.error("ObjectBox on-disk open failed: \(String(describing: error), privacy: .public)")
    }

    // 3) Safe dev fallback: in-memory (keeps app from crashing)
    do {
        let mem = try Store(directoryPath: "memory:chunks-dev")
        Logger(subsystem: "com.adamdrew.takenote", category: "OBStoreMaker")
            .info("Using in-memory ObjectBox store (dev fallback)")
        return mem
    } catch {
        Logger(subsystem: "com.adamdrew.takenote", category: "OBStoreMaker")
            .error("ObjectBox in-memory open failed too: \(String(describing: error), privacy: .public)")
        return nil
    }
}

class OBSearchIndex {
    let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "OBSearchIndex"
    )
    private let chunker: WindowChunker
    private let embedder: EmbeddingProvider
    private let store : Store?
    private let box : Box<OBChunk>

    
    init(inMemory: Bool = true) {
        self.chunker = WindowChunker()
        self.embedder = EmbeddingProvider()
        self.store = makeStore()
        guard let s = store else {
            logger.error("OBSearchIndex: store unavailable; running with no search backend")
            fatalError("OB store failed")
        }
        self.box = s.box(for: OBChunk.self)

    }
    
    // MARK: Public API
    
    /// Index 1 note (replace all its chunks)
    func reindex(noteID: UUID, markdown: String) {
        delete(noteID: noteID)
        for chunk in chunker.chunks(for: markdown) {
            let embedding = embedder.embed(chunk.text)
            let obChunk = OBChunk(noteID: noteID, chunk: chunk.text, embedding: embedding)
            do {
                try self.box.put(obChunk)
            } catch {
                logger.error("Error persisting chunk: \(error)")
            }
        }
        logger.debug("Indexed note \(noteID)")
    }
    
    /// Index many notes (replace each note's chunks)
    func reindex(_ notes: [(UUID, String)]) {
        for note in notes {
            reindex(noteID: note.0, markdown: note.1)
        }
    }
    
    /// Destroy all records
    func dropAll() {
        do {
            try self.box.removeAll()
            logger.info("Deleted all chunks from the objectbox store")
        } catch {
            self.logger.error("Error deleting everything from store box: \(error)")
        }
    }
    
    /// Remove a single note’s chunks
    func delete(noteID: UUID) {
        do {
            let query: Query<OBChunk> = try self.box.query {
                OBChunk.noteID == noteID.uuidString
            }.build()
            let chunks: [OBChunk] = try query.find()
            for chunk in chunks {
                try self.box.remove(chunk.id)
            }
            self.logger.info("Removed chunk from store")
        } catch {
            self.logger.error("Error deleting chunks: \(error)")
        }
    }
    
    /// Back-compat alias
    func searchNatural(_ text: String, limit: Int = 5) -> [SearchHit] {
        return search(text, limit: limit)
    }
    
    /// Dense (cosine) search over embedded chunks with light anchor scoping
    func search(_ query: String, limit: Int = 5) -> [SearchHit] {
        guard let embedding = embedder.embed(query) else {
            logger.error("Error generating query embedding")
            return []
        }
        do {
            let query = try box
                .query { OBChunk.embedding.nearestNeighbors(queryVector: embedding, maxCount: 4) }
                .build()
            let results = try query.findWithScores()
            let searchHits: [SearchHit] = results.map { result in
                let id = result.object.id
                let uuid = UUID(uuidString: result.object.noteID)
                let chunk = result.object.chunk
                return SearchHit(id: Int64(id), noteID: uuid ?? UUID(), chunk: chunk)
            }
            logger.info("OBS: Found \(results.count) search results")
            return searchHits
        } catch {
            logger.error("Error performing vector search: \(error)")
        }
        return []
    }
    

}
