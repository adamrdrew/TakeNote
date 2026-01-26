//
//  NoteImageManager.swift
//  TakeNote
//
//  Created by Adam Drew on 9/9/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
class NoteImageManager {
    var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func ingestImage(from url: URL, note: Note) -> NoteImage? {
        guard url.isFileURL else { return nil }
        guard let type = UTType(filenameExtension: url.pathExtension),
            type.conforms(to: .image)
        else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }

        let mimeType = type.preferredMIMEType ?? "application/octet-stream"
        let image = NoteImage(data: data, mimeType: mimeType, referenceCount: 1)
        modelContext.insert(image)
        let link = NoteImageLink(sourceNote: note, image: image)
        modelContext.insert(link)
        return image
    }

    func updateImageLinks(for note: Note) {
        let existingLinks = getLinksForSourceNote(note)
        let existingUUIDs = Set(
            existingLinks.compactMap { $0.image?.uuid }
        )
        let currentUUIDs = Set(extractImageUUIDs(from: note.content))

        let linksToRemove = existingLinks.filter { link in
            guard let uuid = link.image?.uuid else { return true }
            return !currentUUIDs.contains(uuid)
        }

        for link in linksToRemove {
            if let image = link.image {
                image.referenceCount = max(0, image.referenceCount - 1)
                if image.referenceCount == 0 {
                    modelContext.delete(image)
                }
            }
            modelContext.delete(link)
        }

        let uuidsToAdd = currentUUIDs.subtracting(existingUUIDs)
        if !uuidsToAdd.isEmpty {
            let images = getImagesForUUIDs(uuidsToAdd)
            let imageByUUID = makeUUIDImageMap(images)
            for uuid in uuidsToAdd {
                guard let image = imageByUUID[uuid] else { continue }
                let link = NoteImageLink(sourceNote: note, image: image)
                image.referenceCount += 1
                modelContext.insert(link)
            }
        }

        try? modelContext.save()
    }

    func removeImageLinks(for note: Note) {
        let existingLinks = getLinksForSourceNote(note)
        for link in existingLinks {
            if let image = link.image {
                image.referenceCount = max(0, image.referenceCount - 1)
                if image.referenceCount == 0 {
                    modelContext.delete(image)
                }
            }
            modelContext.delete(link)
        }
        try? modelContext.save()
    }

    private func extractImageUUIDs(from text: String) -> [UUID] {
        let pattern =
            #/(?i)takenote:\/\/image\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/#
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

    private func getLinksForSourceNote(_ note: Note) -> [NoteImageLink] {
        let uuid = note.uuid
        return
            (try? modelContext.fetch(
                FetchDescriptor<NoteImageLink>(
                    predicate: #Predicate { $0.sourceNote?.uuid == uuid }
                )
            )) ?? []
    }

    private func getImagesForUUIDs(_ uuids: Set<UUID>) -> [NoteImage] {
        return
            (try? modelContext.fetch(
                FetchDescriptor<NoteImage>(
                    predicate: #Predicate { uuids.contains($0.uuid) }
                )
            )) ?? []
    }

    private func makeUUIDImageMap(_ images: [NoteImage]) -> [UUID: NoteImage] {
        var imageByUUID: [UUID: NoteImage] = [:]
        for image in images {
            imageByUUID[image.uuid] = image
        }
        return imageByUUID
    }
}
