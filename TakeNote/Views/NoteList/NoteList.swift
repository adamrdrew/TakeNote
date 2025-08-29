//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import AudioToolbox  // For system sounds
import SwiftData
import SwiftUI

extension FocusedValues {
    @Entry var noteDeleteRegistry: CommandRegistry?
    @Entry var noteRenameRegistry: CommandRegistry?
    @Entry var noteCopyMarkdownLinkRegistry: CommandRegistry?
    @Entry var noteOpenEditorWindowRegistry: CommandRegistry?
    @Entry var selectedNotes: Set<Note>?
}

private struct NoteCopyMarkdownLinkRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct NoteDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct NoteRenameRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct NoteOpenEditorWindowRegistry: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
extension EnvironmentValues {
    var noteDeleteRegistry: CommandRegistry {
        get { self[NoteDeleteRegistryKey.self] }
        set { self[NoteDeleteRegistryKey.self] = newValue }
    }
    var noteCopyMarkdownLinkRegistry: CommandRegistry {
        get { self[NoteCopyMarkdownLinkRegistryKey.self] }
        set { self[NoteCopyMarkdownLinkRegistryKey.self] = newValue }
    }
    var noteRenameRegistry: CommandRegistry {
        get { self[NoteRenameRegistryKey.self] }
        set { self[NoteRenameRegistryKey.self] = newValue }
    }
    var noteOpenEditorWindowRegistry: CommandRegistry {
        get { self[NoteOpenEditorWindowRegistry.self] }
        set { self[NoteOpenEditorWindowRegistry.self] = newValue }
    }
}

struct NoteList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM
    @State var showFileImportError: Bool = false
    @State var fileImportErrorMessage: String = ""
    @State var noteSearchText: String = ""

    @State var noteDeleteRegistry: CommandRegistry = CommandRegistry()
    @State var noteRenameRegistry: CommandRegistry = CommandRegistry()
    @State var noteCopyMarkdownLinkRegistry: CommandRegistry = CommandRegistry()
    @State var noteOpenEditorWindowRegistry: CommandRegistry = CommandRegistry()

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

    func playSystemErrorSound() {
        #if os(macOS)
            AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)
        #endif
    }

    func pasteNote(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id
            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }
            // Add the destination folder to the note and save
            if let nc = takeNoteVM.selectedContainer {
                if nc.isTag {
                    // Error sound cues the user that they tried to do something
                    // that isn't allowed
                    playSystemErrorSound()
                    return
                }
                // If the note is in the hidden buffer folder then this
                // is a cut and paste, so we wholesale move the note into
                // the selected container
                if note.folder == takeNoteVM.bufferFolder {
                    note.folder = nc
                    continue
                }
                // If the note.folder isn't the buffer folder then this is a
                // copy and paste and we need a new note
                let newNote = Note(folder: nc)
                newNote.content = note.content
                newNote.title = note.title
                newNote.aiSummary = note.aiSummary
                newNote.createdDate = note.createdDate
                newNote.starred = note.starred
                newNote.contentHash = note.contentHash
                newNote.aiSummaryIsGenerating = note.aiSummaryIsGenerating
                modelContext.insert(newNote)
            }
        }
        takeNoteVM.onMoveToFolder()
        do {
            try modelContext.save()
        } catch {
            return
        }
    }

    func folderHasStarredNotes() -> Bool {
        return takeNoteVM.selectedContainer?.notes.contains { $0.starred }
            ?? false
    }

    var folderSymbol: String {
        guard let container = takeNoteVM.selectedContainer else {
            return "folder"
        }
        if container.isTrash {
            return "trash"
        }
        if container.isTag {
            return "tag"
        }
        return "folder"
    }

    var noteCountLabel: String {
        let noNotes = "No notes"
        guard let container = takeNoteVM.selectedContainer else {
            return noNotes
        }
        if container.notes.isEmpty {
            return noNotes
        }
        if container.notes.count == 1 {
            return "\(String(describing: container.notes.count)) note"
        }
        return "\(String(describing: container.notes.count)) notes"
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM

        VStack {
            if takeNoteVM.selectedContainer != nil {

                HStack {
                    VStack(alignment: .leading) {
                        Label(
                            takeNoteVM.selectedContainer?.name
                                ?? "No folder selected",
                            systemImage: folderSymbol
                        )
                        .font(.title)
                        .fontWeight(.bold)
                        Text(noteCountLabel)
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding()
            }

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
                if filteredNotes.isEmpty == false {
                    Section(header: Text("Notes").font(.headline)) {
                        ForEach(filteredNotes, id: \.self) { note in
                            if !note.starred {
                                NoteListEntry(
                                    note: note,
                                )
                            }

                        }
                    }
                }

            }
            /// Add the command registries to the environment so that the list entries can access them
            .environment(\.noteDeleteRegistry, noteDeleteRegistry)
            .environment(
                \.noteCopyMarkdownLinkRegistry,
                noteCopyMarkdownLinkRegistry
            )
            .environment(\.noteRenameRegistry, noteRenameRegistry)
            .environment(
                \.noteOpenEditorWindowRegistry,
                noteOpenEditorWindowRegistry
            )

            /// Make the command registries the focused values for this list so that the menubar commands can access them
            .focusedValue(\.noteDeleteRegistry, noteDeleteRegistry)
            .focusedValue(\.noteRenameRegistry, noteRenameRegistry)
            .focusedValue(
                \.noteCopyMarkdownLinkRegistry,
                noteCopyMarkdownLinkRegistry
            )
            .focusedValue(
                \.noteOpenEditorWindowRegistry,
                noteOpenEditorWindowRegistry
            )

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
                // We look in the previously selected notes so we can generate summaries, link objects, and reindex
                for note in oldValue {
                    Task { await note.generateSummary() }
                    if note.contentHasChanged() {
                        search.reindex(note: note)
                        NoteLinkManager(modelContext: modelContext)
                            .generateLinksFor(note)
                    }
                }

            }
        }
        #if os(macOS)
            .copyable(
                takeNoteVM.selectedNotes.map {
                    NoteIDWrapper(id: $0.persistentModelID)
                }
            )
            .cuttable(for: NoteIDWrapper.self) {
                // Stash the notes in the hidden buffer folder
                for note: Note in takeNoteVM.selectedNotes {
                    if let bf = takeNoteVM.bufferFolder {
                        note.folder = bf
                    }
                }
                try? modelContext.save()
                return takeNoteVM.selectedNotes.map {
                    NoteIDWrapper(id: $0.persistentModelID)
                }
            }

            .pasteDestination(for: NoteIDWrapper.self) { wrappedIDs in
                pasteNote(wrappedIDs)
            }
        #endif
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
