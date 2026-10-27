//
//  NoteImageManager.swift
//  TakeNote
//
//  Created by Adam Drew on 2/27/26.
//

import Foundation
import os
import SwiftData

@MainActor
final class NoteImageManager {

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "NoteImageManager")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: Public Methods

    /// Deletes any NoteImage records whose imageUUID is not referenced by any non-trashed, non-buffered note's content.
    /// Culling is lazy and eventually consistent: runs on note deselection and after emptyTrash.
    func cullOrphanedImages() {
        // Fetch all NoteImage records
        let allImages: [NoteImage]
        do {
            allImages = try modelContext.fetch(FetchDescriptor<NoteImage>())
        } catch {
            logger.error("Failed to fetch NoteImage records: \(error.localizedDescription)")
            return
        }

        if allImages.isEmpty {
            return
        }

        // Fetch all notes that are not in Trash and not in Buffer
        let activePredicate = #Predicate<Note> {
            $0.folder?.isTrash != true && $0.folder?.isBuffer != true
        }
        let activeNotes: [Note]
        do {
            activeNotes = try modelContext.fetch(
                FetchDescriptor<Note>(predicate: activePredicate)
            )
        } catch {
            logger.error("Failed to fetch active notes while culling images: \(error.localizedDescription)")
            return
        }

        // Build the set of all referenced image UUIDs by scanning each note's content
        let imageURLPattern =
            #/(?i)takenote:\/\/image\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/#

        var referencedUUIDs = Set<UUID>()
        for note in activeNotes {
            for match in note.content.matches(of: imageURLPattern) {
                let uuidSubstring = match.1
                if let uuid = UUID(uuidString: String(uuidSubstring)) {
                    referencedUUIDs.insert(uuid)
                }
            }
        }

        // Delete any NoteImage whose imageUUID is not in the referenced set
        var deletedCount = 0
        for image in allImages {
            if !referencedUUIDs.contains(image.imageUUID) {
                modelContext.delete(image)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            do {
                try modelContext.save()
                logger.info("Culled \(deletedCount) orphaned NoteImage record(s).")
            } catch {
                logger.error("Failed to cull orphaned NoteImage records: \(error.localizedDescription)")
            }
        }
    }
}
