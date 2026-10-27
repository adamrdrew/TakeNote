//
//  FolderListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI

struct FolderListEntry: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Environment(\.containerRenameRegistry) private var containerRenameRegistry
    @Environment(\.containerDeleteRegistry) private var containerDeleteRegistry
    let folder: NoteContainer
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) private var folders: [NoteContainer]
    @State private var inRenameMode: Bool = false
    @State private var newName: String = ""
    @State private var showEmptyTrashWarning: Bool = false
    @Query() private var allNotes: [Note]
    @State private var showEditDetailsPopover: Bool = false
    @FocusState private var nameInputFocused: Bool

    @State private var inDeleteMode: Bool = false

    private func startDelete() {
        inDeleteMode = true
    }

    private func deleteFolder() {
        let folderID = folder.persistentModelID
        takeNoteVM.folderDelete(
            folder,
            folders: folders,
            modelContext: modelContext
        )
        modelContext.delete(folder)
        containerDeleteRegistry?.unregisterCommand(id: folderID)
        containerRenameRegistry?.unregisterCommand(id: folderID)
        saveChanges()
    }

    private func startRename() {
        inRenameMode = true
        newName = folder.name
        nameInputFocused = true
    }

    private func finishRename() {
        inRenameMode = false
        folder.name = newName
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
        }
    }

    private func dropNoteToFolder(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id
            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }
            if folder.isStarred {
                if note.starred {
                    continue
                }
                takeNoteVM.noteStarredToggle(note, modelContext: modelContext)
            } else {
                // Add the destination folder to the note and save
                note.folder = folder
            }
        }
        do {
            try modelContext.save()
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
            return
        }
        takeNoteVM.onMoveToFolder()
    }

    private var noteCount: Int {
        if folder.isAllNotes {
            return allNotes.filter {
                $0.folder?.isTrash != true && $0.folder?.isBuffer != true
            }.count
        }
        return folder.notes.count
    }

    private var folderSymbolColor: Color {
        return folder.isSystemFolder ? .takeNotePink : folder.getColor()
    }

    var body: some View {
        HStack {
            if inRenameMode {
                TextField("New Folder Name", text: $newName)
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
                HStack {
                    HStack(spacing: 8) {
                        SidebarContainerIcon(
                            systemName: folder.getSystemImageName(),
                            color: folderSymbolColor
                        )
                        Text(folder.name)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    HStack {
                        Text(noteCount, format: .number)
                            .foregroundStyle(.secondary)
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            containerDeleteRegistry?.registerCommand(
                id: folder.persistentModelID,
                command: startDelete
            )
            containerRenameRegistry?.registerCommand(
                id: folder.persistentModelID,
                command: startRename
            )
        }
        .onDisappear {
            containerDeleteRegistry?.unregisterCommand(
                id: folder.persistentModelID
            )
            containerRenameRegistry?.unregisterCommand(
                id: folder.persistentModelID
            )
        }
        .popover(
            isPresented: $showEditDetailsPopover,
            attachmentAnchor: .point(.center),
            arrowEdge: .leading
        ) {
            NoteContainerDetailsEditor(
                showColorPopover: $showEditDetailsPopover,
                noteContainer: folder
            )
        }
        .dropDestination(for: NoteIDWrapper.self, isEnabled: true) {
            wrappedIDs,
            _ in
            dropNoteToFolder(wrappedIDs)
        }
        #if os(iOS)
            .swipeActions(edge: .trailing) {
                if folder.canBeDeleted {
                    Button(
                        role: .destructive,
                        action: {
                            deleteFolder()
                        }
                    ) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        #endif
        .contextMenu {
            if !folder.isSystemFolder {
                Button(action: {
                    showEditDetailsPopover = true
                }) {

                    Label("Edit Details", systemImage: "gear")
                }
            }
            if folder.canBeDeleted {
                Button(
                    role: .destructive,
                    action: {
                        inDeleteMode = true
                    }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
            if !folder.isSystemFolder {
                Button(action: {
                    startRename()
                }) {
                    Label("Rename", systemImage: "square.and.pencil")
                }
            }
            if folder.isTrash && noteCount > 0 {
                Button(action: {
                    showEmptyTrashWarning = true
                }) {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
            }
        }
        .alert(
            "Empty Trash?",
            isPresented: $showEmptyTrashWarning
        ) {
            Button("Empty Trash", role: .destructive) {
                takeNoteVM.emptyTrash(modelContext)
                showEmptyTrashWarning = false
            }
            Button("Cancel", role: .cancel) {
                showEmptyTrashWarning = false
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            "Delete Folder?",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        } message: {
            Text(
                "Notes in \(folder.name) will be moved to the trash.",
                comment: "Folder deletion confirmation message; the variable is the folder name."
            )
        }
    }

}
