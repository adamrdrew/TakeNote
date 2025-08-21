//
//  Sidebar.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftData
import SwiftUI

struct Sidebar: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var search: SearchIndexService
    @Environment(TakeNoteVM.self) var takeNoteVM
    
    @State var folderSectionExpanded : Bool = true
    @State var tagSectionExpanded : Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""
    
    var tagsExist: Bool = false
    var onMoveToFolder: () -> Void = { }
    var onFolderDelete: (NoteContainer) -> Void = { NoteContainer in  }
    var onTagDelete: (NoteContainer) -> Void = { NoteContainer in  }
    var onEmptyTrash: () -> Void = { }
    var onAddFolder: () -> Void = { }
    var onAddTag: () -> Void = { }
    
    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        List(selection: $takeNoteVM.selectedContainer) {
            Section(
                isExpanded: $folderSectionExpanded,
                content: {
                    FolderList(
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
            let importResult = folderImport(items: items, modelContext: modelContext, searchIndex: search)
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
            Button(action: onAddFolder) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add Folder")
            AddTagButton(action: onAddTag)
        }
    }
}
