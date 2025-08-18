//
//  Sidebar.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftData
import SwiftUI

struct SidebarCommands {
    var addFolder: () -> Void
    var addTag: () -> Void
}

struct SidebarCommandsFocusedKey: FocusedValueKey {
    typealias Value = SidebarCommands
}

extension FocusedValues {
    var sidebarCommands: SidebarCommandsFocusedKey.Value? {
        get { self[SidebarCommandsFocusedKey.self] }
        set { self[SidebarCommandsFocusedKey.self] = newValue }
    }
}

struct DeleteCommand {
    var canBeDeleted: () -> Bool
    var delete: () -> Void
}

struct DeleteCommandFocusedKey: FocusedValueKey {
    typealias Value = DeleteCommand
}

extension FocusedValues {
    var deleteCommand: DeleteCommandFocusedKey.Value? {
        get { self[DeleteCommandFocusedKey.self] }
        set { self[DeleteCommandFocusedKey.self] = newValue }
    }
}

struct Sidebar: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var search: SearchIndexService

    @Binding var selectedContainer: NoteContainer?

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTrash
        }
    ) var trashFolders: [NoteContainer]

    var tagsExist: Bool = false
    var onMoveToFolder: () -> Void = {}
    var onFolderDelete: (NoteContainer) -> Void = { NoteContainer in }
    var onTagDelete: (NoteContainer) -> Void = { NoteContainer in }
    var onEmptyTrash: () -> Void = {}
    var onAddFolder: () -> Void = {}
    var onAddTag: () -> Void = {}

    var body: some View {
        List(selection: $selectedContainer) {
            Section(
                isExpanded: $folderSectionExpanded,
                content: {
                    FolderList(
                        selectedContainer: $selectedContainer,
                        onMoveToFolder: onMoveToFolder,
                        onDelete: onFolderDelete,
                        onEmptyTrash: onEmptyTrash
                    )

                },
                header: {
                    Text("Folders")
                }
            )
            .headerProminence(.increased)

            if tagsExist {
                Section(
                    isExpanded: $tagSectionExpanded,
                    content: {
                        TagList(
                            onDelete: onTagDelete
                        )
                    },
                    header: {
                        Text("Tags")
                    }
                ).headerProminence(.increased)

            }
        }
        .focusedValue(
            \.deleteCommand,
            .init(
                canBeDeleted: {
                    guard let sc = selectedContainer else { return false }
                    if sc.isTrash { return false }
                    if sc.isInbox { return false }
                    return sc.canBeDeleted
                },
                delete: {
                    /// I hate this. But After hours of trying I see no other way
                    /// SwiftUI wont let me place this code at the right level of abstraction: the FolderListEntry
                    /// It only allows it here, on the List, not the ListItems
                    /// So even though we have delete code elsewhere I had to do this insane bullshit
                    /// Patches Welcome...
                    guard let sc = selectedContainer else { return }
                    guard sc.canBeDeleted == true else { return }
                    if sc.isTrash == true { return }
                    if sc.isInbox == true { return }
                    if sc.isTag == true {
                        modelContext.delete(sc)
                        selectedContainer = nil
                        return
                    }
                    guard let trash = trashFolders.first else { return }
                    sc.notes.forEach { note in
                        note.folder = trash
                    }
                    modelContext.delete(sc)
                    selectedContainer = nil

                }
            )
        )
        .dropDestination(for: URL.self, isEnabled: true) { items, location in
            var importResult = folderImport(
                items: items,
                modelContext: modelContext,
                searchIndex: search
            )
            importErrorMessage = importResult.toString()
            showImportError = importResult.errorsEncountered
        }
        .alert(importErrorMessage, isPresented: $showImportError) {
            Button("OK") {
                showImportError.toggle()
            }
        }
        .listStyle(.sidebar)
        .focusedSceneValue(
            \.sidebarCommands,
            .init(
                addFolder: onAddFolder,
                addTag: onAddTag
            )
        )
        .toolbar {
            Button(action: onAddFolder) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add Folder")
            AddTagButton(action: onAddTag)

        }
    }
}
