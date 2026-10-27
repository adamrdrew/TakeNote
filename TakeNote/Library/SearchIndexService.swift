import CoreSpotlight
import Foundation
import os
import SwiftData

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
    private let spotlight: any NoteSearchIndex
    @ObservationIgnored
    private var spotlightDelegate: NoteSpotlightDelegate?

    var hits: [SearchHit] = []
    var isIndexing: Bool = false
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")
    @ObservationIgnored
    private var indexingTask: Task<Void, Never>?
    @ObservationIgnored
    private var pendingFullReindex: [NoteSearchEntity]?
    @ObservationIgnored
    private var pendingReset = false
    @ObservationIgnored
    private var pendingNoteEntities: [UUID: NoteSearchEntity] = [:]
    @ObservationIgnored
    private var pendingDeletedNoteIDs: Set<UUID> = []
    @ObservationIgnored
    private var searchGeneration = 0

    init(spotlight: any NoteSearchIndex = NoteSpotlightIndex()) {
        self.spotlight = spotlight
        if !AppBootstrapper.isRunningTests {
            removeLegacySQLiteIndex()
        }
    }

    deinit {
        indexingTask?.cancel()
    }

    nonisolated static func isIndexable(_ note: Note) -> Bool {
        note.folder?.isTrash != true
            && note.folder?.isBuffer != true
            && note.folder?.isArchive != true
    }

    func reindex(note: Note) {
        guard Self.isIndexable(note) else {
            deleteFromIndex(noteID: note.uuid)
            return
        }
        pendingDeletedNoteIDs.remove(note.uuid)
        pendingNoteEntities[note.uuid] = NoteSearchEntity(note: note)
        scheduleIndexing()
    }

    func configureSpotlightDelegate(modelContainer: ModelContainer) {
        let delegate = NoteSpotlightDelegate(modelContainer: modelContainer)
        spotlightDelegate = delegate
        CSSearchableIndex.default().indexDelegate = delegate
    }

    var searchableIndexDelegate: (any CSSearchableIndexDelegate)? {
        spotlightDelegate
    }

    func reindexAll(_ notes: [Note]) {
        pendingFullReindex = notes.filter(Self.isIndexable).map(NoteSearchEntity.init(note:))
        pendingReset = true
        pendingNoteEntities.removeAll()
        pendingDeletedNoteIDs.removeAll()
        scheduleIndexing()
    }

    func deleteFromIndex(noteID: UUID) {
        pendingNoteEntities[noteID] = nil
        pendingDeletedNoteIDs.insert(noteID)
        hits.removeAll { $0.noteID == noteID }
        scheduleIndexing()
    }

    func deleteAllFromIndex() {
        pendingReset = true
        pendingFullReindex = nil
        pendingNoteEntities.removeAll()
        pendingDeletedNoteIDs.removeAll()
        hits.removeAll()
        scheduleIndexing()
    }

    private var hasPendingIndexing: Bool {
        pendingReset || pendingFullReindex != nil
            || !pendingNoteEntities.isEmpty || !pendingDeletedNoteIDs.isEmpty
    }

    private func scheduleIndexing() {
        guard indexingTask == nil else { return }
        indexingTask = Task { [weak self] in
            // Debounce requests, but never cancel an in-flight Spotlight write.
            // One worker serializes resets, snapshots, deletions and edits.
            while let self, hasPendingIndexing, !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(750))
                } catch {
                    break
                }
                let reset = pendingReset
                let snapshot = pendingFullReindex
                let deletedIDs = Array(pendingDeletedNoteIDs)
                let entities = Array(pendingNoteEntities.values)
                pendingReset = false
                pendingFullReindex = nil
                pendingDeletedNoteIDs.removeAll()
                pendingNoteEntities.removeAll()

                isIndexing = true
                if reset { await spotlight.deleteAll() }
                if let snapshot { await spotlight.reindex(snapshot) }
                if !deletedIDs.isEmpty { await spotlight.delete(noteIDs: deletedIDs) }
                if !entities.isEmpty { await spotlight.reindex(entities) }
                isIndexing = false
            }
            self?.indexingTask = nil
        }
    }

    func waitForPendingIndexing() async {
        await indexingTask?.value
    }

    func search(_ text: String, limit: Int = 20) async -> [SearchHit] {
        searchGeneration += 1
        let generation = searchGeneration
        await waitForPendingIndexing()
        guard !Task.isCancelled else { return [] }
        let results = await spotlight.search(text, limit: limit)
        guard !Task.isCancelled, generation == searchGeneration else { return [] }
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
