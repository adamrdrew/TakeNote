//
//  TagListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

internal struct TagListEntry: View {
    var tag: NoteContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @State private var inDeleteMode: Bool = false

    @Environment(\.containerRenameRegistry) var containerRenameRegistry
    @Environment(\.containerDeleteRegistry) var containerDeleteRegistry
    @Environment(\.tagSetColorRegistry) var tagSetColorRegistry

    @State private var inRenameMode: Bool = false
    @State private var newTagName: String = ""
    @State private var showEditDetailsPopover: Bool = false
    @FocusState private var nameInputFocused: Bool

    func startDelete() {
        inDeleteMode = true
    }

    func deleteTag() {
        modelContext.delete(tag)
        containerDeleteRegistry.unregisterCommand(id: tag.id)
        containerRenameRegistry.unregisterCommand(id: tag.id)
        try? modelContext.save()
        takeNoteVM.onTagDelete(tag)
    }

    func startRename() {
        inRenameMode = true
        nameInputFocused = true
        newTagName = tag.name
    }

    func finishRename() {
        inRenameMode = false
        tag.name = newTagName
        try? modelContext.save()
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
        }
        do {
            try modelContext.save()
        } catch {
            return
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if inRenameMode {
                TextField("New Tag Name", text: $newTagName)
                    .focused($nameInputFocused)
                    .onSubmit {
                        finishRename()
                    }
                    .onChange(of: nameInputFocused) { _, focused in
                        if !focused {
                            finishRename()
                        }
                    }
            } else {
                Image(systemName: "tag.fill")
                    .foregroundStyle(tag.getColor())
                Text(tag.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                Spacer()
                HStack {
                    Text("\(tag.notes.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            containerDeleteRegistry.registerCommand(
                id: tag.id,
                command: startDelete
            )
            containerRenameRegistry.registerCommand(
                id: tag.id,
                command: startRename
            )
            tagSetColorRegistry.registerCommand(
                id: tag.id,
                command: {
                    showEditDetailsPopover = true
                }
            )
        }
        .onDisappear {
            containerDeleteRegistry.unregisterCommand(
                id: tag.id
            )
            containerRenameRegistry.unregisterCommand(
                id: tag.id
            )
            tagSetColorRegistry.unregisterCommand(
                id: tag.id
            )
        }
        #if os(iOS)
            .swipeActions(edge: .trailing) {
                if tag.canBeDeleted {
                    Button(
                        role: .destructive,
                        action: {
                            deleteTag()
                        }
                    ) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        #endif
        .popover(
            isPresented: $showEditDetailsPopover,
            attachmentAnchor: .point(.center),
            arrowEdge: .bottom
        ) {
            NoteContainerDetailsEditor(
                showColorPopover: $showEditDetailsPopover,
                noteContainer: tag
            )
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
            Button(action: startRename) {
                Label("Rename Tag", systemImage: "pencil")
            }
            Button(action: {
                showEditDetailsPopover = true
            }) {

                Label("Edit Details", systemImage: "gear")
            }
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
