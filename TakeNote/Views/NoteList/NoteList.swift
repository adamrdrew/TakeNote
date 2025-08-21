//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct NoteList: View {
    @Binding var selectedNotes: Set<Note>
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM
    @State var showFileImportError: Bool = false
    @State var fileImportErrorMessage: String = ""
    @State var noteSearchText: String = ""
    
    
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

    @EnvironmentObject private var search: SearchIndexService

    var onTrash: ((_ deletedNote: Note) -> Void) = { Note in }
    var onSelect: ((Note) -> Void) = { Note in }

    func addNote() {
        guard let folder = takeNoteVM.selectedContainer else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        try? modelContext.save()
    }

    func folderHasStarredNotes() -> Bool {
        return takeNoteVM.selectedContainer?.notes.contains { $0.starred } ?? false
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        VStack {

            List(selection: $selectedNotes) {
                if folderHasStarredNotes() {
                    Section(header: Text("Favorites").font(.headline)) {
                        ForEach(filteredNotes, id: \.self) { note in
                            if note.starred {
                                NoteListEntry(
                                    note: note,
                                    onTrash: onTrash
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
                                onTrash: onTrash
                            )
                        }

                    }
                }
            }
            .searchable(text: $noteSearchText, prompt: "Search")
            .onChange(of: selectedNotes) { oldValue, newValue in
                // We look in the new selected notes array so we can run the callback on the selected notes
                if newValue.count == 1 {
                    if let note = newValue.first {
                        onSelect(note)
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
