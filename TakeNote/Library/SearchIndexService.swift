import Foundation
import os

// MARK: Result type
struct SearchHit: Identifiable, Hashable {
    let id: String
    let noteID: UUID
    let chunk: String
}

@MainActor
@Observable
class SearchIndexService {
    private let spotlight = NoteSpotlightIndex()

    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    var logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")
    private var reindexTask: Task<Void, Never>?

    init() {
        removeLegacySQLiteIndex()
    }

    func reindex(note: Note) {
        let entity = NoteSearchEntity(note: note)
        Task {
            await spotlight.reindex(entity)
        }
    }

    func reindexAll(_ notes: [Note]) {
        let spotlightEntities = notes.map(NoteSearchEntity.init(note:))

        reindexTask?.cancel()
        logger.info("Spotlight search reindex running.")
        isIndexing = true
        reindexTask = Task {
            await spotlight.reindex(spotlightEntities)
            if Task.isCancelled {
                isIndexing = false
                return
            }
            isIndexing = false
            #if DEBUG
            logger.info("Spotlight search reindex complete. \(spotlightEntities.count) notes indexed.")
            #endif
        }
    }

    func deleteFromIndex(noteID: UUID) {
        logger.debug("Removing note \(noteID) from Spotlight index.")
        Task {
            await spotlight.delete(noteID: noteID)
        }
    }

    func deleteAllFromIndex() {
        logger.debug("Removing all notes from Spotlight index.")
        Task {
            await spotlight.deleteAll()
        }
    }

    func search(_ text: String, limit: Int = 20) async -> [SearchHit] {
        let results = await spotlight.search(text, limit: limit)
        hits = results
        return results
    }

    func searchNoteIDs(_ text: String, limit: Int = 500) async -> [UUID] {
        let hits = await search(text, limit: limit)
        var seen = Set<UUID>()
        var result: [UUID] = []
        for hit in hits {
            if seen.insert(hit.noteID).inserted {
                result.append(hit.noteID)
            }
        }
        return result
    }

    private func removeLegacySQLiteIndex() {
        let fileManager = FileManager.default
        guard
            let appSupportURL = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        else {
            return
        }

        let legacyURLs = [
            appSupportURL
                .appendingPathComponent("TakeNote", isDirectory: true)
                .appendingPathComponent("search.sqlite", isDirectory: false),
            appSupportURL
                .appendingPathComponent("TakeNote", isDirectory: true)
                .appendingPathComponent("search.sqlite-shm", isDirectory: false),
            appSupportURL
                .appendingPathComponent("TakeNote", isDirectory: true)
                .appendingPathComponent("search.sqlite-wal", isDirectory: false)
        ]

        for url in legacyURLs where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
                logger.info("Removed legacy search index file: \(url.lastPathComponent)")
            } catch {
                logger.warning("Could not remove legacy search index file \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

}
