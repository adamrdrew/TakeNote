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
    @Environment(\.colorScheme) var colorScheme
    @Environment(TakeNoteVM.self) var takeNoteVM
    @Environment(\.containerRenameRegistry) var containerRenameRegistry
    @Environment(\.containerDeleteRegistry) var containerDeleteRegistry
    var folder: NoteContainer
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]
    @State private var inRenameMode: Bool = false
    @State private var newName: String = ""
    @State private var showEmptyTrashWarning: Bool = false
    @FocusState private var nameInputFocused: Bool

    @State var inDeleteMode: Bool = false
    
    func startDelete() {
        inDeleteMode = true
    }

    func deleteFolder() {
        takeNoteVM.folderDelete(
            folder,
            folders: folders,
            modelContext: modelContext
        )
        modelContext.delete(folder)
        containerDeleteRegistry.unregisterCommand(id: folder.id)
        containerRenameRegistry.unregisterCommand(id: folder.id)
        try? modelContext.save()
    }

    func startRename() {
        inRenameMode = true
        newName = folder.name
        nameInputFocused = true
    }

    func finishRename() {
        inRenameMode = false
        folder.name = newName
        try? modelContext.save()
    }

    func dropNoteToFolder(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id
            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }
            if folder.isStarred {
                if note.starred {
                    return
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
            return
        }
        takeNoteVM.onMoveToFolder()
    }
    
    var iconColor: Color {
        if folder == takeNoteVM.selectedContainer {
            return .primary
        }
        return .takeNotePink
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
                    Label {
                        Text(folder.name)
                            .foregroundColor(colorScheme == .light ? Color.primary : Color.white)
                    } icon: {
                        Image(systemName: folder.getSystemImageName())
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    HStack {
                        Text("\(folder.notes.count)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            containerDeleteRegistry.registerCommand(
                id: folder.id,
                command: startDelete
            )
            containerRenameRegistry.registerCommand(
                id: folder.id,
                command: startRename
            )
        }
        .onDisappear {
            containerDeleteRegistry.unregisterCommand(
                id: folder.id
            )
            containerRenameRegistry.unregisterCommand(
                id: folder.id
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
            if !folder.isTrash && !folder.isInbox {
                Button(action: {
                    startRename()
                }) {
                    Label("Rename", systemImage: "square.and.pencil")
                }
            }
            if folder.isTrash && folder.notes.count > 0 {
                Button(action: {
                    showEmptyTrashWarning = true
                }) {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
            }
        }
        .alert(
            "Are you sure you want to empty the trash? This action cannot be undone.",
            isPresented: $showEmptyTrashWarning
        ) {
            Button("Empty Trash", role: .destructive) {
                takeNoteVM.emptyTrash(modelContext)
                showEmptyTrashWarning = false
            }
            Button("Cancel", role: .cancel) {
                showEmptyTrashWarning = false
            }
        }
        .alert(
            "Are you sure you want to delete \(folder.name)? Notes in this folder will be moved to the trash.",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }
    }

}
