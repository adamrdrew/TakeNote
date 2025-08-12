//
//  NoteLabelListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

struct TagListEntry: View {
    var tag: NoteContainer
    @Environment(\.modelContext) private var modelContext

    
    func dropNoteToTag(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id

            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }

            // Add the destination tag to the note and save
            note.tag = tag
            do {
                try modelContext.save()
            } catch {
                return
            }

        }
    }

    var body: some View {
        HStack(spacing: 8) {
            NoteLabelBadge(noteLabel: tag)
            Text(tag.name)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Label("\(tag.notes.count)", systemImage: "note.text")
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .dropDestination(for: NoteIDWrapper.self, isEnabled: true) {
            wrappedIDs,
            _ in
            dropNoteToTag(wrappedIDs)
        }
    }
}
