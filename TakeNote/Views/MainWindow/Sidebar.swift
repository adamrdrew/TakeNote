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

struct Sidebar: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var search: SearchIndexService

    @Binding var selectedContainer: NoteContainer?

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""

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
        .focusedSceneValue(\.sidebarCommands, .init(
            addFolder: onAddFolder,
            addTag: onAddTag
        ))
        .toolbar {
            Button(action: onAddFolder) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .help("Add Folder")
            AddTagButton(action: onAddTag)

        }
    }
}
