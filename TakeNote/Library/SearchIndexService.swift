import Foundation
import os

// MARK: Result type
struct SearchHit: Identifiable, Hashable, Sendable {
    let id: String
    let noteID: UUID
    let noteTitle: String?
    let chunk: String

    nonisolated var displayTitle: String {
        guard let noteTitle, !noteTitle.isEmpty else {
            return String(
                localized: "Note",
                comment: "Fallback title for a note search result with no title."
            )
        }
        return noteTitle
    }
}

@MainActor
@Observable
final class SearchIndexService {
    @ObservationIgnored
    private let spotlight = NoteSpotlightIndex()

    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")
    @ObservationIgnored
    private var fullReindexTask: Task<Void, Never>?
    @ObservationIgnored
    private var noteReindexTask: Task<Void, Never>?
    @ObservationIgnored
    private var noteDeletionTask: Task<Void, Never>?
    @ObservationIgnored
    private var pendingNoteEntities: [UUID: NoteSearchEntity] = [:]
    @ObservationIgnored
    private var pendingDeletedNoteIDs: Set<UUID> = []
    @ObservationIgnored
    private let noteReindexDelay: Duration = .milliseconds(750)
    @ObservationIgnored
    private let noteDeletionDelay: Duration = .milliseconds(250)
    @ObservationIgnored
    private let fullReindexDelay: Duration = .seconds(2)

    init() {
        removeLegacySQLiteIndex()
    }

    deinit {
        fullReindexTask?.cancel()
        noteReindexTask?.cancel()
        noteDeletionTask?.cancel()
    }

    func reindex(note: Note) {
        let entity = NoteSearchEntity(note: note)
        pendingNoteEntities[note.uuid] = entity
        schedulePendingNoteReindex()
    }

    func reindexAll(_ notes: [Note]) {
        let spotlightEntities = notes.map(NoteSearchEntity.init(note:))

        fullReindexTask?.cancel()
        noteReindexTask?.cancel()
        noteDeletionTask?.cancel()
        pendingNoteEntities.removeAll()
        pendingDeletedNoteIDs.removeAll()

        fullReindexTask = Task {
            do {
                try await Task.sleep(for: fullReindexDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            isIndexing = true
            defer { isIndexing = false }
            logger.debug("Spotlight search full reindex running for \(spotlightEntities.count) notes.")
            await spotlight.reindex(spotlightEntities)
            guard !Task.isCancelled else { return }
            #if DEBUG
            logger.debug("Spotlight search full reindex complete. \(spotlightEntities.count) notes indexed.")
            #endif
        }
    }

    private func schedulePendingNoteReindex() {
        noteReindexTask?.cancel()
        noteReindexTask = Task {
            do {
                try await Task.sleep(for: noteReindexDelay)
            } catch {
                return
            }
            await flushPendingNoteReindex()
        }
    }

    private func flushPendingNoteReindex() async {
        guard !pendingNoteEntities.isEmpty else { return }

        let entities = Array(pendingNoteEntities.values)
        pendingNoteEntities.removeAll()

        isIndexing = true
        defer { isIndexing = false }
        logger.debug("Spotlight search incremental reindex running for \(entities.count) notes.")
        await spotlight.reindex(entities)
    }

    func deleteFromIndex(noteID: UUID) {
        logger.debug("Removing note \(noteID) from Spotlight index.")
        pendingNoteEntities[noteID] = nil
        pendingDeletedNoteIDs.insert(noteID)
        hits.removeAll { $0.noteID == noteID }
        schedulePendingNoteDeletions()
    }

    func deleteAllFromIndex() {
        logger.debug("Removing all notes from Spotlight index.")
        fullReindexTask?.cancel()
        noteReindexTask?.cancel()
        noteDeletionTask?.cancel()
        pendingNoteEntities.removeAll()
        pendingDeletedNoteIDs.removeAll()
        hits.removeAll()

        noteDeletionTask = Task {
            await spotlight.deleteAll()
        }
    }

    private func schedulePendingNoteDeletions() {
        noteDeletionTask?.cancel()
        noteDeletionTask = Task {
            do {
                try await Task.sleep(for: noteDeletionDelay)
            } catch {
                return
            }
            await flushPendingNoteDeletions()
        }
    }

    private func flushPendingNoteDeletions() async {
        guard !pendingDeletedNoteIDs.isEmpty else { return }

        let noteIDs = Array(pendingDeletedNoteIDs)
        pendingDeletedNoteIDs.removeAll()

        logger.debug("Spotlight search deletion running for \(noteIDs.count) notes.")
        await spotlight.delete(noteIDs: noteIDs)
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
        let appSupportURL: URL
        do {
            appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            logger.warning("Could not resolve Application Support directory: \(error.localizedDescription)")
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
