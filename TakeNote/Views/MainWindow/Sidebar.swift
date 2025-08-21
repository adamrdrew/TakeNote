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

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""

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

            if takeNoteVM.tagsExist {
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
            Button(action: takeNoteVM.addFolder) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add Folder")
            AddTagButton(action: takeNoteVM.addTag)
        }
    }
}
