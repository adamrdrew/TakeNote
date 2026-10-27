//
//  LinkManager.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import Foundation
import os
import SwiftData

@MainActor
final class NoteLinkManager {

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "NoteLinkManager")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: Public Methods

    func getNotesThatLinkTo(_ note: Note) -> [Note] {
        let links = getLinksForDestinationNote(note)
        return links.compactMap(\.sourceNote)
    }

    func notesLinkToDestination(_ note: Note) -> Bool {
        getNotesThatLinkTo(note).isEmpty == false
    }

    func generateLinksFor(_ note: Note) {
        let linksFromThisNote = getLinksForSourceNote(note)

        if !linksFromThisNote.isEmpty {
            deleteLinks(links: linksFromThisNote)
        }

        let linkToUUIDs = extractNoteUUIDs(from: note.content)
        if linkToUUIDs.isEmpty {
            return
        }

        createLinksForUUIDs(linkToUUIDs, note: note)
    }

    // MARK: Private Methods

    private func extractNoteUUIDs(from text: String) -> [UUID] {
        // `(?i)` makes the URL match case-insensitive.
        let pattern =
            #/(?i)takenote:\/\/note\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/#
        var seen = Set<UUID>()
        var result: [UUID] = []

        for match in text.matches(of: pattern) {
            let uuidSub = match.1
            if let uuid = UUID(uuidString: String(uuidSub)),
                seen.insert(uuid).inserted
            {
                result.append(uuid)
            }
        }
        return result
    }

    private func getLinksForSourceNote(_ note: Note) -> [NoteLink] {
        let uuid = note.uuid
        do {
            return try modelContext.fetch(
                FetchDescriptor<NoteLink>(
                    predicate: #Predicate { $0.sourceNote?.uuid == uuid }
                )
            )
        } catch {
            logger.error("Failed to fetch source note links: \(error.localizedDescription)")
            return []
        }
    }

    private func getLinksForDestinationNote(_ note: Note) -> [NoteLink] {
        let uuid = note.uuid
        do {
            return try modelContext.fetch(
                FetchDescriptor<NoteLink>(
                    predicate: #Predicate { $0.destinationNote?.uuid == uuid}
                )
            )
        } catch {
            logger.error("Failed to fetch destination note links: \(error.localizedDescription)")
            return []
        }
    }

    private func deleteLinks(links: [NoteLink]) {
        for link in links {
            modelContext.delete(link)
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to delete note links: \(error.localizedDescription)")
        }
    }

    private func getNotesForUUIDs(_ linkToUUIDs: [UUID]) -> [Note]? {
        var results: [Note] = []
        for uuid in linkToUUIDs {
            do {
                let notes = try modelContext.fetch(
                    FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == uuid })
                )
                guard let note = notes.first else { continue }
                results.append(note)
            } catch {
                logger.error("Failed to fetch note for link UUID \(uuid): \(error.localizedDescription)")
            }
        }
        return results.isEmpty ? nil : results
    }

    private func makeUUIDNoteMap(_ notes: [Note]) -> [UUID: Note] {
        var noteByUUID: [UUID: Note] = [:]
        for n in notes {
            noteByUUID[n.uuid] = n
        }
        return noteByUUID
    }

    func createLinksForUUIDs(_ linkToUUIDs: [UUID], note: Note) {
        let fetchedTargets = getNotesForUUIDs(linkToUUIDs)
        guard let targets = fetchedTargets else { return }

        let noteByUUID = makeUUIDNoteMap(targets)

        for linkToUUID in linkToUUIDs {
            guard let targetNote = noteByUUID[linkToUUID] else { continue }
            let newLink = NoteLink(
                sourceNote: note,
                destinationNote: targetNote
            )
            logger.info("Created a link from \(note.uuid) to \(targetNote.uuid)")
            modelContext.insert(newLink)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to create note links: \(error.localizedDescription)")
        }
    }

}
