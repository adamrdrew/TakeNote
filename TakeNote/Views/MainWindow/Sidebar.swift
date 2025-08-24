//
//  Sidebar.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftData
import SwiftUI

extension FocusedValues {
    @Entry var folderItemController: FolderItemController?
    @Entry var selectedNoteContainer: NoteContainer?
}

@Observable
internal final class FolderItemController {
    var deleteCommands: [PersistentIdentifier: () -> Void] = [:]
    var renameCommands: [PersistentIdentifier: () -> Void] = [:]

    func registerDeleteCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        deleteCommands[id] = command
    }

    func registerRenameCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        renameCommands[id] = command
    }

    func runDeleteCommand(id: PersistentIdentifier) {
        deleteCommands[id]?()
    }

    func runRenameCommand(id: PersistentIdentifier) {
        renameCommands[id]?()
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
    @State var deleteCommands: [PersistentIdentifier: () -> Void] = [:]
    @State var renameCommands: [PersistentIdentifier: () -> Void] = [:]
    
    @State var folderItemController = FolderItemController()

    func registerDeleteCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        deleteCommands[id] = command
    }

    func registerRenameCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        renameCommands[id] = command
    }

    func runDeleteCommand(id: PersistentIdentifier) {
        deleteCommands[id]?()
    }

    func runRenameCommand(id: PersistentIdentifier) {
        renameCommands[id]?()
    }

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
        .focusedValue(\.folderItemController, folderItemController)
        .focusedValue(\.selectedNoteContainer, takeNoteVMBinding.selectedContainer)
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
        .environment(folderItemController)
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
