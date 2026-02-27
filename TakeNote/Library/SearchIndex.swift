// ChatGPT wrote this
// I wrote the initial implementation which was very simple and bare bones
// ChatGPT re-wrote it
// I have made changes and improvements manually over time

import Foundation
import SQLite  // SQLite.swift
import os
import NaturalLanguage



/// Minimal full-text index for your notes.
/// FTS5 table with two columns: note_id (UNINDEXED), chunk (searchable).
internal final class SearchIndex {
    
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "Database")
    
    
    let stopWords: [String] = ["i", "me", "my", "myself", "we", "our", "ours",
    "ourselves", "you", "your", "yours", "yourself", "yourselves", "he", "him",
    "his", "himself", "she", "her", "hers", "herself", "it", "its", "itself",
    "they", "them", "their", "theirs", "themselves", "what", "which", "who",
    "whom", "this", "that", "these", "those", "am", "is", "are", "was", "were",
    "be", "been", "being", "have", "has", "had", "having", "do", "does", "did",
    "doing", "a", "an", "the", "and", "but", "if", "or", "because", "as", "until",
    "while", "of", "at", "by", "for", "with", "about", "against", "between",
    "into", "through", "during", "before", "after", "above", "below", "to",
    "from", "up", "down", "in", "out", "on", "off", "over", "under", "again",
    "further", "then", "once", "here", "there", "when", "where", "why", "how",
    "all", "any", "both", "each", "few", "more", "most", "other", "some", "such",
    "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "s",
    "t", "can", "will", "just", "don", "should", "now",
    "note", "notes"]

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
    init(
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
    func reindex(noteID: UUID, markdown: String) {
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

    func dropAll() {
        do {
            // Fast path: wipe all rows from the FTS table.
            // (This preserves the schema and is safe for both in-memory & on-disk.)
            try db.run(fts.delete())

            // FTS5 maintenance: compact internal index structures.
            // This is optional; ignore if it ever errors on older SQLite builds.
            try db.run("INSERT INTO fts(fts) VALUES('optimize')")

            // Reclaim disk space (if on-disk). These are no-ops for in-memory.
            // Must be outside a transaction.
            try db.run("PRAGMA wal_checkpoint(TRUNCATE)")
            try db.run("VACUUM")
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
                try db.run("PRAGMA wal_checkpoint(TRUNCATE)")
                try db.run("VACUUM")
            } catch {
                logger.error("SearchIndex dropAll error: \(error.localizedDescription)")
            }
        }
    }
    /// Bulk (re)index many notes efficiently.
    func reindex(_ notes: [(UUID, String)]) {
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
    func delete(noteID: UUID) {
        do {
            try db.run(fts.filter(note_id == noteID.uuidString).delete())
            logger.debug("Note \(noteID) deleted from search index")
        } catch { logger.error("SearchIndex delete error: \(error.localizedDescription)") }
    }

    // MARK: Search

    // Add alongside your SearchHit and other methods

    
    func normalizeQuery(_ text: String, locale: Locale = .init(identifier: "en")) -> [String] {
        // Normalize apostrophes/diacritics for consistency
        let pre = text.replacingOccurrences(of: "’", with: "'")
                      .folding(options: .diacriticInsensitive, locale: locale)

        let tagger = NLTagger(tagSchemes: [.tokenType, .lemma, .language])
        tagger.string = pre
        tagger.setLanguage(.english, range: pre.startIndex..<pre.endIndex)

        var terms: [String] = []
        tagger.enumerateTags(
            in: pre.startIndex..<pre.endIndex,
            unit: .word,
            scheme: .tokenType,
            options: [.omitPunctuation, .omitWhitespace]
        ) { _, range in
            // Get lemma if available; else the raw token
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
            let raw = pre[range].lowercased()
            let lemma = (lemmaTag?.rawValue ?? raw).lowercased()

            // Strip possessive/apostrophes inside words
            let cleaned = lemma.replacingOccurrences(of: "'s", with: "")
                               .replacingOccurrences(of: "'", with: "")

            // Drop stopwords & empties
            if !cleaned.isEmpty, !stopWords.contains(cleaned) {
                terms.append(cleaned)
            }
            return true
        }
        return terms
    }
    
    /// Natural-language search:
    /// - splits on non-alphanumerics (so punctuation can't break MATCH),
    /// - ORs the tokens (forgiving),
    /// - adds "*" to tokens >= 3 chars (prefix match).
    func searchNatural(_ text: String, limit: Int = 5) -> [SearchHit] {
        
        let tokens = normalizeQuery(text)
        
        // 2) Add prefix wildcard to longer tokens (keeps small ones as-is)
        let starred = tokens.map { $0.count >= 3 ? "\($0)*" : $0 }

        // 3) Be forgiving: join with OR so any token can match
        //    (FTS5 will still rank results; you're already ordering by bm25)
        let safeQuery = starred.joined(separator: " OR ")

        #if DEBUG
        logger.debug("FTS query: \(safeQuery) (from tokens: \(tokens))")
        #endif

        let results = search(safeQuery, limit: limit)
        
        
        
        #if DEBUG
        logger.debug("\(results.count) search hits found.")
        #endif

        // 4) Delegate to your existing FTS search
        return results
    }

    /// Simple FTS5 search. Supports plain words or FTS syntax (phrases, prefix*).
    func search(_ query: String, limit: Int = 5) -> [SearchHit] {
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

    // MARK: Diagnostics

    var rowCount: Int {
        (try? db.scalar(fts.count)) ?? 0
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

}
