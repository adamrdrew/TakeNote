//
//  TagListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

struct TagListEntry: View {
    var tag: NoteContainer
    @Environment(\.modelContext) private var modelContext
    @State var inDeleteMode: Bool = false
    var onDelete: ((_ deletedFolder: NoteContainer) -> Void) = { deletedFolder in }

    
    func deleteTag() {
        modelContext.delete(tag)
        try? modelContext.save()
        onDelete(tag)
    }
    
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
                .font(.headline)
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
        .alert(
            "Are you sure you want to delete \(tag.name)?",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteTag()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }
        .contextMenu {
            if tag.canBeDeleted {
                Button(
                    role: .destructive,
                    action: {
                        inDeleteMode = true
                    }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
