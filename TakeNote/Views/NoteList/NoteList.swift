//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI


extension FocusedValues {
    @Entry var noteDeleteRegistry: CommandRegistry?
    @Entry var noteRenameRegistry: CommandRegistry?
    @Entry var selectedNotes: Set<Note>?
}

private struct NoteDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct NoteRenameRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
extension EnvironmentValues {
    var noteDeleteRegistry: CommandRegistry {
        get { self[NoteDeleteRegistryKey.self] }
        set { self[NoteDeleteRegistryKey.self] = newValue }
    }
    var noteRenameRegistry: CommandRegistry {
        get { self[NoteRenameRegistryKey.self] }
        set { self[NoteRenameRegistryKey.self] = newValue }
    }
}

struct NoteList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM
    @State var showFileImportError: Bool = false
    @State var fileImportErrorMessage: String = ""
    @State var noteSearchText: String = ""
    
    @State var noteDeleteRegistry : CommandRegistry = CommandRegistry()
    @State var noteRenameRegistry : CommandRegistry = CommandRegistry()
    
    var filteredNotes: [Note] {
        if noteSearchText.isEmpty {
            takeNoteVM.selectedContainer?.notes ?? []
        } else {
            takeNoteVM.selectedContainer?.notes.filter {
                $0.title.localizedStandardContains(noteSearchText)
                    || $0.content.localizedStandardContains(noteSearchText)
            } ?? []
        }
    }

    @Environment(SearchIndexService.self) private var search

    func folderHasStarredNotes() -> Bool {
        return takeNoteVM.selectedContainer?.notes.contains { $0.starred } ?? false
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        VStack {

            List(selection: $takeNoteVM.selectedNotes) {
                if folderHasStarredNotes() {
                    Section(header: Text("Favorites").font(.headline)) {
                        ForEach(filteredNotes, id: \.self) { note in
                            if note.starred {
                                NoteListEntry(
                                    note: note,
                                )

                            }
                        }
                    }

                }
                Section(
                    header: Text("Notes").font(.headline)
                ) {
                    ForEach(filteredNotes, id: \.self) { note in
                        if !note.starred {
                            NoteListEntry(
                                note: note,
                            )
                        }

                    }
                }
            }
            /// Add the command registries to the environment so that the list entries can access them
            .environment(\.noteDeleteRegistry, noteDeleteRegistry)
            .environment(\.noteRenameRegistry, noteRenameRegistry)
            /// Make the command registries the focused values for this list so that the menubar commands can access them
            .focusedValue(\.noteDeleteRegistry, noteDeleteRegistry)
            .focusedValue(\.noteRenameRegistry, noteRenameRegistry)
            /// Make the selected container available to the menubar commands so we can use its ID to resolve the correct commands in the
            /// command registries
            .focusedValue(
                \.selectedNotes,
                takeNoteVM.selectedNotes
            )
            .searchable(text: $noteSearchText, prompt: "Search")
            .onChange(of: takeNoteVM.selectedNotes) { oldValue, newValue in
                // We look in the new selected notes array so we can run the callback on the selected notes
                if newValue.count == 1 {
                    if let note = newValue.first {
                        takeNoteVM.onNoteSelect(note)
                    }
                }
                // We look in the previously selected notes so we can generate summaries and reindex
                for note in oldValue {
                    Task { await note.generateSummary() }
                    if note.contentHasChanged() {
                        search.reindex(note: note)
                    }
                }

            }
        }
        .dropDestination(for: URL.self, isEnabled: true) { items, location in
            let result = fileImport(
                items: items,
                modelContext: modelContext,
                searchIndex: search,
                folder: takeNoteVM.selectedContainer!
            )
            showFileImportError = result.errorsEncountered
            fileImportErrorMessage = result.toString()
        }
        .alert(fileImportErrorMessage, isPresented: $showFileImportError) {
            Button("OK") {
                showFileImportError = false
            }
        }

    }
}
