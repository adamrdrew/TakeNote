//
//  LinkManager.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
class LinkManager {
    
    var modelContext : ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: Public Methods
    
    func getLinksToDestinationNote(_ note: Note) -> [Link] {
        let links = getLinksForDestinationNote(note)
        guard let linksToThisNote = links else { return [] }
        return linksToThisNote
    }
    
    func generateLinksFor(_ note: Note) {
        /// Get the link models for this note
        let linksFromThisNote = getLinksForSourceNote(note)
        
        /// Make sure we have results, if not bail
        guard let links = linksFromThisNote else { return }
        
        /// Delete all the link models for this note
        deleteLinks(links: links)
        
        /// Find all of the markdown links in this note's content
        let linkToUUIDs = extractNoteUUIDs(from: note.content)
        if linkToUUIDs.isEmpty {
            /// No to-links found. Bail
            return
        }

        /// Create the link models for this note
        createLinksForUUIDs(linkToUUIDs, note: note)
    }
    
    // MARK: Private Methods
    
    /// ChatGPT wrote this. I don't write this kind of thing lol
    private func extractNoteUUIDs(from text: String) -> [UUID] {
        /// case-insensitive: (?i)
        let pattern =
            #/(?i)takenote:\/\/note\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/#
        var seen = Set<UUID>()
        var result: [UUID] = []

        for match in text.matches(of: pattern) {
            /// First capture group is the UUID substring
            let uuidSub = match.1
            if let uuid = UUID(uuidString: String(uuidSub)),
                seen.insert(uuid).inserted
            {
                result.append(uuid)
            }
        }
        return result
    }
    
    private func getLinksForSourceNote(_ note: Note) -> [Link]? {
        /// Query all of the links that have this note as the source
        let sourceUUID = note.uuid
        let linksFromThisNote: [Link]? = try? modelContext.fetch(
            FetchDescriptor<Link>(
                predicate: #Predicate { $0.sourceNote.uuid == sourceUUID }
            )
        )
        return linksFromThisNote
    }
    
    private func getLinksForDestinationNote(_ note: Note) -> [Link]? {
        /// Query all of the links that have this note as the source
        let destinationUUID = note.uuid
        let linksFromThisNote: [Link]? = try? modelContext.fetch(
            FetchDescriptor<Link>(
                predicate: #Predicate { $0.destinationNote.uuid == destinationUUID }
            )
        )
        return linksFromThisNote
    }
    
    private func deleteLinks(links: [Link]) {
        /// Delete all of these links
        for link in links {
            modelContext.delete(link)
        }
    }

    private func getNotesForUUIDs(_ linkToUUIDs: [UUID]) -> [Note]? {
        /// Fetch all target notes in one query
        let uuidSet = Set(linkToUUIDs)
        let fetchedTargets: [Note]? = try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { uuidSet.contains($0.uuid) }
            )
        )
        return fetchedTargets
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
        /// Make sure we have results, if not bail
        guard let targets = fetchedTargets else { return }
        
        let noteByUUID = makeUUIDNoteMap(targets)

        /// Create links for any UUIDs that resolved to a Note
        for linkToUUID in linkToUUIDs {
            guard let targetNote = noteByUUID[linkToUUID] else { continue }
            let newLink = Link(sourceNote: note, destinationNote: targetNote)
            modelContext.insert(newLink)
        }
    }
    

}
