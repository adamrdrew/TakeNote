//
//  TagListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

struct TagListEntry: View {
    let tag: NoteContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @State private var inDeleteMode: Bool = false

    @Environment(\.containerRenameRegistry) private var containerRenameRegistry
    @Environment(\.containerDeleteRegistry) private var containerDeleteRegistry
    @Environment(\.tagSetColorRegistry) private var tagSetColorRegistry

    @State private var inRenameMode: Bool = false
    @State private var newTagName: String = ""
    @State private var showEditDetailsPopover: Bool = false
    @FocusState private var nameInputFocused: Bool

    private func startDelete() {
        inDeleteMode = true
    }

    private func deleteTag() {
        let tagID = tag.persistentModelID
        modelContext.delete(tag)
        containerDeleteRegistry?.unregisterCommand(id: tagID)
        containerRenameRegistry?.unregisterCommand(id: tagID)
        if saveChanges() {
            takeNoteVM.onTagDelete(tag)
        }
    }

    private func startRename() {
        inRenameMode = true
        nameInputFocused = true
        newTagName = tag.name
    }

    private func finishRename() {
        inRenameMode = false
        tag.name = newTagName
        saveChanges()
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
            return false
        }
    }

    private func dropNoteToTag(_ wrappedIDs: [NoteIDWrapper]) {
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
            takeNoteVM.presentError(error.localizedDescription)
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
                SidebarContainerIcon(
                    systemName: "tag.fill",
                    color: tag.getColor()
                )
                Text(tag.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                Spacer()
                HStack {
                    Text(tag.notes.count, format: .number)
                        .foregroundStyle(.secondary)
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            containerDeleteRegistry?.registerCommand(
                id: tag.persistentModelID,
                command: startDelete
            )
            containerRenameRegistry?.registerCommand(
                id: tag.persistentModelID,
                command: startRename
            )
            tagSetColorRegistry?.registerCommand(
                id: tag.persistentModelID,
                command: {
                    showEditDetailsPopover = true
                }
            )
        }
        .onDisappear {
            containerDeleteRegistry?.unregisterCommand(
                id: tag.persistentModelID
            )
            containerRenameRegistry?.unregisterCommand(
                id: tag.persistentModelID
            )
            tagSetColorRegistry?.unregisterCommand(
                id: tag.persistentModelID
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
        .padding(.vertical, 2)
        .dropDestination(for: NoteIDWrapper.self, isEnabled: true) {
            wrappedIDs,
            _ in
            dropNoteToTag(wrappedIDs)
        }
        .alert(
            "Delete Tag?",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteTag()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        } message: {
            Text(
                "Delete \(tag.name)?",
                comment: "Tag deletion confirmation message; the variable is the tag name."
            )
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
