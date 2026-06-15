//
//  SnapshotController.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//

import Foundation
import SwiftData
import WidgetKit
import os

struct NoteSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var uuid: UUID
    var title: String
    var excerpt: String
    var url: String
}

struct NoteContainerSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var name: String
    var notes: [NoteSnapshot]
    var symbol: String
    var isInbox: Bool = false
    var isStarred: Bool = false
    var totalNoteCount: Int = 0
}

struct Snapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var containers: [NoteContainerSnapshot]
}

enum SnapshotController {
    private static let appGroupID = "group.TakeNote"
    private static let filename = "snapshot.json"
    private static let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "SnapshotController"
    )

    private static var snapshotFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(filename)
    }

    static func readSnapshot() -> Snapshot? {
        guard let snapshotFileURL else {
            logger.warning("Could not resolve snapshot file URL.")
            return nil
        }
        let data: Data
        do {
            data = try Data(contentsOf: snapshotFileURL)
        } catch {
            logger.debug("Could not read snapshot file: \(error.localizedDescription)")
            return nil
        }
        do {
            return try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            logger.warning("Could not decode snapshot file: \(error.localizedDescription)")
            return nil
        }
    }

    private static func writeSnapshotFile(_ snapshot: Snapshot) {
        guard let snapshotFileURL else {
            logger.warning("Could not resolve snapshot file URL.")
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotFileURL, options: [.atomic])
            // nudge all widgets; the system still rate-limits for battery
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("Could not write snapshot file: \(error.localizedDescription)")
        }
    }

    static func takeSnapshot(modelContext: ModelContext) {
        logger.debug("Taking snapshot.")
        let containerFetch = FetchDescriptor<NoteContainer>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let containers: [NoteContainer]
        do {
            containers = try modelContext.fetch(containerFetch)
        } catch {
            logger.error("Could not fetch containers for snapshot: \(error.localizedDescription)")
            return
        }
        
        var containerSnapshots: [NoteContainerSnapshot] = []
        for container in containers {
            if container.notes.isEmpty { continue }

            // Take the 5 most recently updated notes
            let topNotes = container
                .notes
                .sorted(by: { $0.updatedDate > $1.updatedDate })
                .prefix(5)

            let noteSnapshots: [NoteSnapshot] = topNotes.map { note in
                NoteSnapshot(
                    id: note.persistentModelID,
                    uuid: note.uuid,
                    title: note.title,
                    excerpt: note.aiSummary,
                    url: note.getURL()
                )
            }

            let containerSnapshot = NoteContainerSnapshot(
                id: container.persistentModelID,
                name: container.name,
                notes: noteSnapshots,
                symbol: container.symbol,
                isInbox: container.isInbox,
                isStarred: container.isStarred,
                totalNoteCount: container.notes.count
            )

            containerSnapshots.append(containerSnapshot)
        }

        // Build and write the full snapshot
        let snapshot = Snapshot(
            id: UUID(),
            containers: containerSnapshots
        )
        Self.writeSnapshotFile(snapshot)
    }

}
