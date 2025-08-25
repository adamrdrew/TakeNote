//
//  Sidebar.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftData
import SwiftUI

extension FocusedValues {
    @Entry var containerDeleteRegistry: CommandRegistry?
    @Entry var containerRenameRegistry: CommandRegistry?
    @Entry var selectedNoteContainer: NoteContainer?
}

private struct ContainerDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct ContainerRenameRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}

extension EnvironmentValues {
    var containerDeleteRegistry: CommandRegistry {
        get { self[ContainerDeleteRegistryKey.self] }
        set { self[ContainerDeleteRegistryKey.self] = newValue }
    }
    var containerRenameRegistry: CommandRegistry {
        get { self[ContainerRenameRegistryKey.self] }
        set { self[ContainerRenameRegistryKey.self] = newValue }
    }
}

struct Sidebar: View {
    @Environment(SearchIndexService.self) var search
    @Environment(TakeNoteVM.self) var takeNoteVM
    @Environment(\.modelContext) var modelContext

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""

    @State var containerDeleteRegistry : CommandRegistry = CommandRegistry()
    @State var containerRenameRegistry : CommandRegistry = CommandRegistry()

    var tagsExist: Bool {
        return tags.isEmpty == false
    }

    var body: some View {
        @Bindable var takeNoteVMBinding = takeNoteVM
        List(selection: $takeNoteVMBinding.selectedContainer) {
            Section(
                isExpanded: $folderSectionExpanded,
                content: {
                    FolderList()
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
                        TagList()
                    },
                    header: {
                        Text("Tags")
                    }
                ).headerProminence(.increased)

            }
        }
        /// Add the command registries to the environment so that the list entries can access them
        .environment(\.containerDeleteRegistry, containerDeleteRegistry)
        .environment(\.containerRenameRegistry, containerRenameRegistry)
        /// Make the command registries the focused values for this list so that the menubar commands can access them
        .focusedValue(\.containerDeleteRegistry, containerDeleteRegistry)
        .focusedValue(\.containerRenameRegistry, containerRenameRegistry)
        /// Make the selected container available to the menubar commands so we can use its ID to resolve the correct commands in the
        /// command registries
        .focusedValue(
            \.selectedNoteContainer,
            takeNoteVMBinding.selectedContainer
        )
        .dropDestination(for: URL.self, isEnabled: true) { items, location in
            let importResult = folderImport(
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
        .toolbar {
            Button(action: {
                takeNoteVM.addFolder(modelContext)
            }) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add Folder")
            AddTagButton(action: {
                takeNoteVM.addTag(modelContext: modelContext)
            })
        }
    }
}
