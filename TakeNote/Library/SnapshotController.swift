//
//  SnapshotController.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//

import SwiftData
import SwiftUI
import WidgetKit

struct NoteSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var uuid: UUID
    var title: String
    var url: String
}

struct NoteContainerSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var name: String
    var notes: [NoteSnapshot]
    var symbol: String
    var color: UInt32
    var isInbox: Bool = false
    var isStarred: Bool = false
    var isTag: Bool = false
    var totalNoteCount: Int = 0
}

struct Snapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var generatedAt: Date
    var containers: [NoteContainerSnapshot]
}

class SnapshotController {
    private static let appGroupID = "group.TakeNote"
    private static let filename = "snapshot.json"

    private static var snapshotFileURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent(filename)
    }

    public static func readSnapshot() -> Snapshot? {
        guard let data = try? Data(contentsOf: snapshotFileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private static func writeSnapshotFile(_ snapshot: Snapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotFileURL, options: [.atomic])
            // nudge all widgets; the system still rate-limits for battery
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // swallow or log
            #if DEBUG
                print("WidgetSnapshotIO write error:", error)
            #endif
        }
    }

    public static func takeSnapshot(modelContext: ModelContext) {
        #if DEBUG
        print("Taking snapshot...")
        #endif
        
        let containerFetch = FetchDescriptor<NoteContainer>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let containers = (try? modelContext.fetch(containerFetch)) ?? []
        
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
                    id: note.id,
                    uuid: note.uuid,
                    title: note.title,
                    url: note.getURL()
                )
            }

            let containerSnapshot = NoteContainerSnapshot(
                id: container.id,
                name: container.name,
                notes: noteSnapshots,
                symbol: container.symbol,
                color: container.colorRGBA,
                isInbox: container.isInbox,
                isStarred: container.isStarred,
                isTag: container.isTag,
                totalNoteCount: container.notes.count
            )

            containerSnapshots.append(containerSnapshot)
        }

        // Build and write the full snapshot
        let snapshot = Snapshot(
            id: UUID(),
            generatedAt: Date(),
            containers: containerSnapshots
        )
        Self.writeSnapshotFile(snapshot)
    }

}

