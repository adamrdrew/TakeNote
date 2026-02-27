//
//  NoteImageStore.swift
//  TakeNote
//

import Foundation
import SwiftData
import os

enum NoteImageStore {

    private static let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteImageStore"
    )

    /// Loads the raw image data for a given image UUID from SwiftData.
    /// Returns nil if no matching NoteImage record is found.
    static func loadImage(uuid: UUID, modelContext: ModelContext) -> Data? {
        let descriptor = FetchDescriptor<NoteImage>(
            predicate: #Predicate { $0.imageUUID == uuid }
        )
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first?.imageData
        } catch {
            logger.warning("Failed to fetch NoteImage for UUID \(uuid): \(error)")
            return nil
        }
    }

}
