//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct NoteList: View {
    @Binding var selectedContainer: NoteContainer?
    @Binding var selectedNotes: Set<Note>
    @Environment(\.modelContext) private var modelContext
    @State var showFileImportError: Bool = false
    @State var fileImportErrorMessage: String = ""
    @State var noteSearchText: String = ""
    
    
    var filteredNotes: [Note] {
        if noteSearchText.isEmpty {
            selectedContainer?.notes ?? []
        } else {
            selectedContainer?.notes.filter {
                $0.title.localizedStandardContains(noteSearchText)
                    || $0.content.localizedStandardContains(noteSearchText)
            } ?? []
        }
    }

    @EnvironmentObject private var search: SearchIndexService

    var onTrash: ((_ deletedNote: Note) -> Void) = { Note in }
    var onSelect: ((Note) -> Void) = { Note in }

    func addNote() {
        guard let folder = selectedContainer else { return }
        let note = Note(folder: folder)
        modelContext.insert(note)
        try? modelContext.save()
    }

    func folderHasStarredNotes() -> Bool {
        return selectedContainer?.notes.contains { $0.starred } ?? false
    }

    var body: some View {
        VStack {

            List(selection: $selectedNotes) {
                if folderHasStarredNotes() {
                    Section(header: Text("Favorites").font(.headline)) {
                        ForEach(filteredNotes, id: \.self) { note in
                            if note.starred {
                                NoteListEntry(
                                    note: note,
                                    selectedContainer: selectedContainer,
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
                                selectedContainer: selectedContainer,
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
            var noteImported = false
            var errorEncountered = false
            for url in items {
                if url.pathExtension != "md" && url.pathExtension != "txt" {
                    errorEncountered = true
                    fileImportErrorMessage =
                        "Unsupported file: \(url.lastPathComponent). Only .md and .txt files are supported."
                    continue
                }
                guard
                    let fileContents = try? String(
                        contentsOf: url,
                        encoding: .utf8
                    )
                else {
                    fileImportErrorMessage = "Failed to read file contents"
                    errorEncountered = true
                    continue
                }
                guard let folder = selectedContainer else {
                    fileImportErrorMessage = "No folder selected"
                    errorEncountered = true
                    continue
                }
                let newNote = Note(folder: folder)
                newNote.title = url.lastPathComponent
                newNote.content = fileContents
                modelContext.insert(newNote)
                Task { await newNote.generateSummary() }
                search.reindex(note: newNote)
                noteImported = true
            }
            if !noteImported {
                fileImportErrorMessage =
                    "No valid notes imported: \(fileImportErrorMessage)"
                showFileImportError = true
                return
            }
            showFileImportError = errorEncountered
            do {
                try modelContext.save()
            } catch {
                fileImportErrorMessage = "Failed to save new note: \(error)"
                showFileImportError = true
            }
        }
        .alert(fileImportErrorMessage, isPresented: $showFileImportError) {
            Button("OK") {
                showFileImportError = false
            }
        }

    }
}
