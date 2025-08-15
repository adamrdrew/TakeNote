import Foundation
import SQLite  // SQLite.swift
import os

/// Minimal full-text index for your notes.
/// FTS5 table with two columns: note_id (UNINDEXED), chunk (searchable).
public final class SearchIndex {
    
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "Database")

    // MARK: Result type
    public struct SearchHit: Identifiable {
        public let id: Int64  // rowid inside FTS table
        public let noteID: UUID
        public let chunk: String  // the stored chunk text
    }

    // MARK: Schema (DSL handles)
    private let fts = VirtualTable("fts")
    private let rowid = Expression<Int64>("rowid")  // implicit rowid on FTS
    private let note_id = Expression<String>("note_id")  // UUID as string
    private let chunk = Expression<String>("chunk")

    // Computed expression for ranking (tiny raw expr; DSL doesn’t wrap bm25())
    private let bm25 = Expression<Double>("bm25(fts)")

    // MARK: State
    private var db: Connection!
    private let chunker: WindowChunker

    // MARK: Init
    /// - Parameters:
    ///   - chunker: how to split long notes (defaults to ~1000 chars)
    ///   - inMemory: handy for tests
    ///   - appSupportSubdir: folder under ~/Library/Application Support
    public init(
        chunker: WindowChunker = .init(),
        inMemory: Bool = false,
        appSupportSubdir: String = "TakeNote"
    ) throws {
        self.chunker = chunker

        if inMemory {
            db = try Connection(.inMemory)
        } else {
            let url = try Self.appSupportURL(
                subdir: appSupportSubdir,
                filename: "search.sqlite"
            )
            db = try Connection(url.path)
            logger.info("Search index database connected")
        }

        // Single Connection is already thread-safe (SQLite.swift serializes ops).
        db.busyTimeout = 5  // seconds

        // Create the FTS table if needed (DSL)
        let cfg = FTS5Config()
            .column(note_id, [.unindexed])
            .column(chunk)
        try db.run(fts.create(.FTS5(cfg), ifNotExists: true))
    }

    // MARK: Indexing

    /// Replace this note’s chunks with fresh ones (call from a background Task).
    public func reindex(noteID: UUID, markdown: String) {
        do {
            try db.transaction {
                try db.run(fts.filter(note_id == noteID.uuidString).delete())
                for c in chunker.chunks(for: markdown) {
                    try db.run(
                        fts.insert(
                            note_id <- noteID.uuidString,
                            chunk <- c.text
                        )
                    )
                }
                logger.debug("Indexed note \(noteID)")
            }
        } catch {
            logger.error("SearchIndex reindex error: \(error.localizedDescription)")
        }
    }

    public func dropAll() {
        do {
            // Fast path: wipe all rows from the FTS table.
            // (This preserves the schema and is safe for both in-memory & on-disk.)
            try db.run(fts.delete())

            // FTS5 maintenance: compact internal index structures.
            // This is optional; ignore if it ever errors on older SQLite builds.
            try? db.run("INSERT INTO fts(fts) VALUES('optimize')")

            // Reclaim disk space (if on-disk). These are no-ops for in-memory.
            // Must be outside a transaction.
            try? db.run("PRAGMA wal_checkpoint(TRUNCATE)")
            try? db.run("VACUUM")
        } catch {
            // If the table doesn't exist or something went sideways, drop & recreate.
            do {
                try db.transaction {
                    try db.run("DROP TABLE IF EXISTS fts")

                    let cfg = FTS5Config()
                        .column(note_id, [.unindexed])
                        .column(chunk)

                    try db.run(fts.create(.FTS5(cfg), ifNotExists: true))
                }
                // After a hard reset, also trim the file.
                try? db.run("PRAGMA wal_checkpoint(TRUNCATE)")
                try? db.run("VACUUM")
            } catch {
                logger.error("SearchIndex dropAll error: \(error.localizedDescription)")
            }
        }
    }
    /// Bulk (re)index many notes efficiently.
    public func reindex(_ notes: [(UUID, String)]) {
        do {
            try db.transaction {
                for (id, md) in notes {
                    try db.run(fts.filter(note_id == id.uuidString).delete())
                    for c in chunker.chunks(for: md) {
                        try db.run(
                            fts.insert(
                                note_id <- id.uuidString,
                                chunk <- c.text
                            )
                        )
                    }
                }
            }
        } catch {
            logger.error("SearchIndex bulk reindex error: \(error.localizedDescription)")
        }
    }

    /// Remove a note from the index entirely.
    public func delete(noteID: UUID) {
        do {
            try db.run(fts.filter(note_id == noteID.uuidString).delete())
        } catch { logger.error("SearchIndex delete error: \(error.localizedDescription)") }
    }

    // MARK: Search

    // Add alongside your SearchHit and other methods

    /// Natural-language search:
    /// - splits on non-alphanumerics (so punctuation can't break MATCH),
    /// - ORs the tokens (forgiving),
    /// - adds "*" to tokens >= 3 chars (prefix match).
    public func searchNatural(_ text: String, limit: Int = 5) -> [SearchHit] {
        // 1) Tokenize by removing punctuation
        let tokens =
            text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return [] }

        // 2) Add prefix wildcard to longer tokens (keeps small ones as-is)
        let starred = tokens.map { $0.count >= 3 ? "\($0)*" : $0 }

        // 3) Be forgiving: join with OR so any token can match
        //    (FTS5 will still rank results; you're already ordering by bm25)
        let safeQuery = starred.joined(separator: " OR ")

        // 4) Delegate to your existing FTS search
        return search(safeQuery, limit: limit)
    }

    /// Simple FTS5 search. Supports plain words or FTS syntax (phrases, prefix*).
    public func search(_ query: String, limit: Int = 5) -> [SearchHit] {
        do {
            let q =
                fts
                .select(rowid, note_id, chunk)
                .filter(fts.match(query))
                .order(bm25.asc)  // ranked by relevance
                .limit(limit)

            var out: [SearchHit] = []
            for row in try db.prepare(q) {
                guard let uuid = UUID(uuidString: row[note_id]) else {
                    continue
                }
                out.append(
                    .init(
                        id: row[rowid],
                        noteID: uuid,
                        chunk: row[chunk]
                    )
                )
            }
            return out
        } catch {
            logger.error("SearchIndex search error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: Helpers

    private static func appSupportURL(subdir: String, filename: String) throws
        -> URL
    {
        let fm = FileManager.default
        var dir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        dir.appendPathComponent(subdir, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename, isDirectory: false)
    }

    // MARK: Debug Helpers

    /// 1) Count rows in FTS quickly
    public func debugCount() -> Int {
        (try? db.scalar("SELECT COUNT(*) FROM fts") as? Int64).map(Int.init)
            ?? -1
    }

    /// 2) Dump a few rows (id, note_id, first 80 chars)
    public func debugDump(limit: Int = 5) {
        do {
            let rowid = Expression<Int64>("rowid")
            let note_id = Expression<String>("note_id")
            let chunk = Expression<String>("chunk")
            for row in try db.prepare(
                fts.select(rowid, note_id, chunk).limit(limit)
            ) {
                let preview = row[chunk].prefix(80).replacingOccurrences(
                    of: "\n",
                    with: "⏎"
                )
                logger.debug(
                    "fts row \(row[rowid])  note_id=\(row[note_id])  chunk=\"\(preview)…\""
                )
            }
            let dc = debugCount()
            logger.debug("fts total rows: \(dc)")
        } catch {
            logger.debug("debugDump error: \(error.localizedDescription)")
        }
    }

}
