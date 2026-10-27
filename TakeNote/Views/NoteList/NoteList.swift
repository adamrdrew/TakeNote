//
//  NoteList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import AudioToolbox  // For system sounds
import SwiftData
import SwiftUI

struct NoteList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @State private var fileImportErrorMessage: String?
    @Query() private var notes: [Note]

    @State private var noteDeleteRegistry: CommandRegistry = CommandRegistry()
    @State private var noteRenameRegistry: CommandRegistry = CommandRegistry()
    @State private var noteStarToggleRegistry: CommandRegistry = CommandRegistry()
    @State private var noteCopyMarkdownLinkRegistry: CommandRegistry = CommandRegistry()
    @State private var noteOpenEditorWindowRegistry: CommandRegistry = CommandRegistry()
    @State private var searchMatchedIDs: [UUID] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var summaryTasks: [PersistentIdentifier: Task<Void, Never>] = [:]
    @State private var summaryTaskTokens: [PersistentIdentifier: UUID] = [:]
    @State private var importTask: Task<Void, Never>?
    @State private var importTaskToken: UUID?

    @Environment(SearchIndexService.self) private var search

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private func isIndexable(_ note: Note) -> Bool {
        note.folder?.isTrash != true
            && note.folder?.isBuffer != true
            && note.folder?.isArchive != true
    }

    private var sortedNotes: [Note] {
        let allNotesSource = notes.filter(isIndexable)
        let filtered: [Note]
        if !takeNoteVM.noteSearchText.isEmpty {
            let matchedSet = Set(searchMatchedIDs)
            filtered = allNotesSource.filter { matchedSet.contains($0.uuid) }
        } else if takeNoteVM.selectedContainer?.isAllNotes == true {
            filtered = allNotesSource
        } else {
            filtered = takeNoteVM.selectedContainer?.notes ?? []
        }
        return filtered.sorted { lhs, rhs in
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
    }

    private func playSystemErrorSound() {
        #if os(macOS)
            AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)
        #endif
    }

    private func pasteNote(_ wrappedIDs: [NoteIDWrapper]) {
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
        do {
            try modelContext.save()
            takeNoteVM.onMoveToFolder()
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
            return
        }
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
            scheduleSummaryGeneration(for: note)
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

    private func scheduleSummaryGeneration(for note: Note) {
        let id = note.persistentModelID
        let token = UUID()
        summaryTasks[id]?.cancel()
        summaryTaskTokens[id] = token
        summaryTasks[id] = Task {
            await note.generateSummary()
            guard summaryTaskTokens[id] == token else { return }
            summaryTasks[id] = nil
            summaryTaskTokens[id] = nil
        }
    }

    private func cancelSummaryGeneration() {
        for task in summaryTasks.values {
            task.cancel()
        }
        summaryTasks.removeAll()
        summaryTaskTokens.removeAll()
    }

    private func importDroppedFiles(_ items: [URL], into folder: NoteContainer) {
        importTask?.cancel()
        let token = UUID()
        importTaskToken = token
        importTask = Task { @MainActor in
            defer {
                if importTaskToken == token {
                    importTask = nil
                    importTaskToken = nil
                }
            }

            let outcome = fileImport(
                items: items,
                modelContext: modelContext,
                searchIndex: search,
                folder: folder
            )
            guard !Task.isCancelled else { return }
            fileImportErrorMessage = outcome.result.errorsEncountered
                ? outcome.result.toString()
                : nil
            await generateImportedNoteSummaries(for: outcome.importedNotes)
        }
    }

    private func cancelImport() {
        importTask?.cancel()
        importTask = nil
        importTaskToken = nil
    }

    private func updateSearchResults(for text: String) {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchMatchedIDs = []
            return
        }

        searchTask = Task {
            let matchedIDs = await search.searchNoteIDs(query)
            guard !Task.isCancelled else { return }
            searchMatchedIDs = matchedIDs
        }
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        let sorted = sortedNotes
        let starred = sorted.filter { $0.starred }
        let unstarred = sorted.filter { !$0.starred }

        VStack {

            List(selection: $takeNoteVM.selectedNotes) {
                NoteListSections(starred: starred, unstarred: unstarred)
            }
            .id(sorted.isEmpty ? "empty" : "populated")
            .safeAreaInset(edge: .top) {
                NoteListHeader()
            }
            // Add the command registries to the environment so that the list entries can access them.
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

            // Make the command registries the focused values for this list so that the menubar commands can access them.
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

            // Make the selected notes available to the menu commands.
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
                do {
                    try modelContext.save()
                } catch {
                    takeNoteVM.presentError(error.localizedDescription)
                }
                return takeNoteVM.selectedNotes.map {
                    NoteIDWrapper(id: $0.persistentModelID)
                }
            }

            .pasteDestination(for: NoteIDWrapper.self) { wrappedIDs in
                pasteNote(wrappedIDs)
            }
        #endif
        .dropDestination(
            for: String.self,
            isEnabled: takeNoteVM.canAddNote
        ) { items, _ in
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
                do {
                    try modelContext.save()
                } catch {
                    takeNoteVM.presentError(error.localizedDescription)
                    return
                }
            }
        }
        .dropDestination(for: URL.self, isEnabled: true) { items, _ in
            guard let selectedContainer = takeNoteVM.selectedContainer else {
                return
            }
            importDroppedFiles(items, into: selectedContainer)
        }
        .alert("Import Failed", item: $fileImportErrorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .onChange(of: notes.count) { _, _ in
            search.reindexAll(notes.filter(isIndexable))
        }
        .onChange(of: takeNoteVM.noteSearchText) { _, newValue in
            updateSearchResults(for: newValue)
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
            if !isCompactLayout,
               !newValue.isEmpty,
               takeNoteVM.selectedContainer !== takeNoteVM.allNotesFolder {
                takeNoteVM.isSearchNavigating = true
                takeNoteVM.selectedContainer = takeNoteVM.allNotesFolder
            }
            #endif
        }
        .onChange(of: takeNoteVM.selectedContainer) { _, _ in
            if takeNoteVM.isSearchNavigating {
                takeNoteVM.isSearchNavigating = false
            } else {
                takeNoteVM.noteSearchText = ""
            }
        }
        .onAppear {
            updateSearchResults(for: takeNoteVM.noteSearchText)
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            cancelSummaryGeneration()
            cancelImport()
        }

    }
}

private struct NoteListSections: View {
    let starred: [Note]
    let unstarred: [Note]

    var body: some View {
        if !starred.isEmpty {
            Section {
                ForEach(starred, id: \.persistentModelID) { note in
                    NoteListEntry(note: note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .tag(note)
                }
            } header: {
                Text("Starred").font(.headline)
            }
        }

        if !unstarred.isEmpty {
            Section {
                ForEach(unstarred, id: \.persistentModelID) { note in
                    NoteListEntry(note: note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .tag(note)
                }
            } header: {
                Text("Notes").font(.headline)
            }
        }
    }
}
