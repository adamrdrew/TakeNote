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
    @Entry var noteStarToggleRegistry: CommandRegistry?
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
private struct NoteStarToggleRegistryKey: EnvironmentKey {
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
    var noteStarToggleRegistry: CommandRegistry {
        get { self[NoteStarToggleRegistryKey.self] }
        set { self[NoteStarToggleRegistryKey.self] = newValue }
    }
    var noteOpenEditorWindowRegistry: CommandRegistry {
        get { self[NoteOpenEditorWindowRegistry.self] }
        set { self[NoteOpenEditorWindowRegistry.self] = newValue }
    }
}

struct NoteList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM
    @State private var showFileImportError: Bool = false
    @State private var fileImportErrorMessage: String = ""
    @Query() var notes: [Note]

    @State private var noteDeleteRegistry: CommandRegistry = CommandRegistry()
    @State private var noteRenameRegistry: CommandRegistry = CommandRegistry()
    @State private var noteStarToggleRegistry: CommandRegistry = CommandRegistry()
    @State private var noteCopyMarkdownLinkRegistry: CommandRegistry = CommandRegistry()
    @State private var noteOpenEditorWindowRegistry: CommandRegistry = CommandRegistry()

    @State private var cachedFilteredNotes: [Note] = []
    @State private var cachedSortedNotes: [Note] = []
    @State private var cachedStarredNotes: [Note] = []
    @State private var cachedUnstarredNotes: [Note] = []

    var showUnstarredNoteList: Bool {
        if cachedSortedNotes.isEmpty {
            return false
        }
        if cachedSortedNotes.contains(where: { !$0.starred }) {
            return true
        }
        return false
    }

    @Environment(SearchIndexService.self) private var search

    private func rebuildNoteCache() {
        let allNotesSource = notes.filter {
            $0.folder?.isTrash != true && $0.folder?.isBuffer != true && $0.folder?.isArchive != true
        }
        let filtered: [Note]
        if !takeNoteVM.noteSearchText.isEmpty {
            // Global search: search across all non-trash/non-buffer notes regardless of selected container
            let matchedIDs = search.searchNoteIDs(takeNoteVM.noteSearchText)
            let matchedSet = Set(matchedIDs)
            let matchedNotes = allNotesSource.filter { matchedSet.contains($0.uuid) }
            let indexMap = Dictionary(uniqueKeysWithValues: matchedIDs.enumerated().map { ($1, $0) })
            filtered = matchedNotes.sorted { (lhs, rhs) in
                (indexMap[lhs.uuid] ?? Int.max) < (indexMap[rhs.uuid] ?? Int.max)
            }
        } else if takeNoteVM.selectedContainer?.isAllNotes == true {
            filtered = allNotesSource
        } else {
            filtered = takeNoteVM.selectedContainer?.notes ?? []
        }
        cachedFilteredNotes = filtered
        cachedSortedNotes = filtered.sorted { lhs, rhs in
            switch takeNoteVM.sortBy {
            case .created:
                if takeNoteVM.sortOrder == .newestFirst {
                    return lhs.createdDate > rhs.createdDate
                } else {
                    return lhs.createdDate < rhs.createdDate
                }
            case .updated:
                if takeNoteVM.sortOrder == .newestFirst {
                    return lhs.updatedDate > rhs.updatedDate
                } else {
                    return lhs.updatedDate < rhs.updatedDate
                }
            }
        }
        cachedStarredNotes = cachedSortedNotes.filter { $0.starred }
        cachedUnstarredNotes = cachedSortedNotes.filter { !$0.starred }
    }

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
                // Direct assignment intentional: this is initializing a copy of an existing note.
                // Note.init(folder:) already triggered WidgetCenter.reloadAllTimelines().
                // Using setTitle()/setContent() would fire redundant widget reloads for each field.
                newNote.content = note.content
                newNote.title = note.title
                newNote.aiSummary = note.aiSummary
                newNote.createdDate = note.createdDate
                newNote.updatedDate = note.updatedDate
                newNote.starred = note.starred
                newNote.contentHash = note.contentHash
                newNote.aiSummaryIsGenerating = note.aiSummaryIsGenerating
                modelContext.insert(newNote)
                search.reindex(note: newNote)
            }
        }
        takeNoteVM.onMoveToFolder()
        do {
            try modelContext.save()
        } catch {
            return
        }
    }

    var folderHasStarredNotes: Bool {
        !cachedStarredNotes.isEmpty
    }

    private func handleNoteSelectionChange(old: Set<Note>, new: Set<Note>) {
        // We look in the new selected notes array so we can run the callback on the selected notes
        if new.count == 1 {
            if let note = new.first {
                takeNoteVM.onNoteSelect(note)
            }
        }
        // We look in the previously selected notes so we can generate summaries, link objects, and reindex
        for note in old {
            Task { await note.generateSummary() }
            if note.contentHasChanged() {
                search.reindex(note: note)
                NoteLinkManager(modelContext: modelContext)
                    .generateLinksFor(note)
                note.setTitle()
            }
        }

        // Cull any NoteImage records that are no longer referenced by any active note
        NoteImageManager(modelContext: modelContext).cullOrphanedImages()
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM

        VStack {

            List(selection: $takeNoteVM.selectedNotes) {

                if folderHasStarredNotes {
                    Section(header: Text("Starred").font(.headline)) {
                        ForEach(cachedStarredNotes, id: \.self) { note in
                            NoteListEntry(
                                note: note,
                            )
                        }
                    }

                }
                if showUnstarredNoteList {
                    Section(header: Text("Notes").font(.headline)) {
                        ForEach(cachedUnstarredNotes, id: \.self) { note in
                            NoteListEntry(
                                note: note,
                            )
                        }
                    }
                }

            }
            .id(cachedSortedNotes.isEmpty ? "empty" : "populated")
            .safeAreaInset(edge: .top) {
                NoteListHeader()
                    .frame(maxHeight: 80)
            }
            /// Add the command registries to the environment so that the list entries can access them
            .environment(\.noteDeleteRegistry, noteDeleteRegistry)
            .environment(
                \.noteCopyMarkdownLinkRegistry,
                noteCopyMarkdownLinkRegistry
            )
            .environment(\.noteRenameRegistry, noteRenameRegistry)
            .environment(\.noteStarToggleRegistry, noteStarToggleRegistry)
            .environment(
                \.noteOpenEditorWindowRegistry,
                noteOpenEditorWindowRegistry
            )

            /// Make the command registries the focused values for this list so that the menubar commands can access them
            .focusedValue(\.noteDeleteRegistry, noteDeleteRegistry)
            .focusedValue(\.noteRenameRegistry, noteRenameRegistry)
            .focusedValue(\.noteStarToggleRegistry, noteStarToggleRegistry)
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
            .onChange(of: takeNoteVM.selectedNotes) { oldValue, newValue in
                handleNoteSelectionChange(old: oldValue, new: newValue)
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
                        note.setFolder(bf)
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
        .dropDestination(for: String.self) { items, _ in
            guard takeNoteVM.canAddNote else { return false }

            var added = false
            for raw in items {
                let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                if let newNote = takeNoteVM.addNote(modelContext) {
                    newNote.setContent(text)
                    search.reindex(note: newNote)
                    added = true
                }
            }

            if added {
                try? modelContext.save()
            }
            return added
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
        .onChange(of: notes.count) { _, _ in
            search.reindexAll(notes.filter { $0.folder?.isArchive != true }.map { ($0.uuid, $0.content) })
        }
        .onChange(of: notes) { _, _ in rebuildNoteCache() }
        .onChange(of: takeNoteVM.noteSearchText) { _, newValue in
            // On Mac/iPad, switch to All Notes as the user types so the sidebar
            // reflects that search is global. On iPhone this is deferred to
            // .onSubmit(of: .search) because changing the container mid-typing
            // collapses the search bar in the stacked NavigationSplitView.
            #if os(macOS)
            if !newValue.isEmpty, takeNoteVM.selectedContainer !== takeNoteVM.allNotesFolder {
                takeNoteVM.isSearchNavigating = true
                takeNoteVM.selectedContainer = takeNoteVM.allNotesFolder
            }
            #else
            if UIDevice.current.userInterfaceIdiom != .phone,
               !newValue.isEmpty,
               takeNoteVM.selectedContainer !== takeNoteVM.allNotesFolder {
                takeNoteVM.isSearchNavigating = true
                takeNoteVM.selectedContainer = takeNoteVM.allNotesFolder
            }
            #endif
            rebuildNoteCache()
        }
        .onChange(of: takeNoteVM.selectedContainer) { _, _ in
            if takeNoteVM.isSearchNavigating {
                takeNoteVM.isSearchNavigating = false
            } else {
                takeNoteVM.noteSearchText = ""
            }
            rebuildNoteCache()
        }
        .onChange(of: takeNoteVM.sortBy) { _, _ in rebuildNoteCache() }
        .onChange(of: takeNoteVM.sortOrder) { _, _ in rebuildNoteCache() }
        .onAppear { rebuildNoteCache() }

    }
}
