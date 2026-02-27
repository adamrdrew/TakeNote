# Steps

## S001: Add `deleteFromIndex(noteID:)` to `SearchIndexService`

**Intent:** Expose a safe, feature-flag-gated deletion method on the service layer so call sites can remove a note from the index by UUID without bypassing the flag check.

**Work:**
- In `SearchIndexService.swift`, add a new method `func deleteFromIndex(noteID: UUID)` that: (1) returns immediately if `chatFeatureFlagEnabled == false`; (2) dispatches `Task { index.delete(noteID: noteID) }`; (3) logs at debug level using the existing `logger`.
- Follow the same internal pattern as `reindex(note:)`.

**Done when:** `SearchIndexService` has a `deleteFromIndex(noteID:)` method that is a no-op when chat is disabled and calls `SearchIndex.delete(noteID:)` otherwise.

---

## S002: Reindex on note creation — `addNote` path in `NoteList` (G1)

**Intent:** Ensure notes created via the primary `addNote()` call path (New Note button, toolbar, FileCommands, AppIntents) are indexed immediately after creation.

**Work:**
- In `NoteList.swift`, in the `.dropDestination(for: String.self)` closure, after `takeNoteVM.addNote(modelContext)` returns a note and `newNote.setContent(text)` is called, call `search.reindex(note: newNote)`.
- Identify all other views that call `takeNoteVM.addNote(modelContext)` directly and add `search.reindex(note:)` after each. Check: `MainWindow` toolbar Add Note button, `FileCommands`, any AppIntents path. For each: retrieve the returned note and call `search.reindex(note:)`.

**Done when:** Every call to `takeNoteVM.addNote()` that returns a non-nil note is immediately followed by `search.reindex(note: note)` at the call site.

---

## S003: Reindex on copy-paste note creation in `NoteList.pasteNote()` (G1 copy-paste)

**Intent:** A note created by copy-paste is a new note that is never indexed until the next bulk reindex.

**Work:**
- In `NoteList.swift`, in `pasteNote()`, after `modelContext.insert(newNote)` (the copy-paste branch), call `search.reindex(note: newNote)`.

**Done when:** `pasteNote()` calls `search.reindex(note: newNote)` after inserting the copied note.

---

## S004: Reindex open note on `scenePhase` background/inactive in `TakeNoteApp` (G2)

**Intent:** When the user quits or backgrounds the app mid-edit, the currently open note's content is captured in the FTS index.

**Work:**
- In `TakeNoteApp.swift`, inside the `.onChange(of: scenePhase)` handler, in the `case .inactive, .background:` branch, after `SnapshotController.takeSnapshot(modelContext: ctx)`, add: if `takeNoteVM.openNote` is non-nil and `chatFeatureFlagEnabled`, call `search.reindex(note: takeNoteVM.openNote!)`.
- The handler already runs on `@MainActor`; both `takeNoteVM` and `search` are accessible in scope (`takeNoteVM` is a `@State` on `TakeNoteApp`; `search` is a `@State` on `TakeNoteApp`).

**Done when:** The `scenePhase` `.inactive`/`.background` handler reindexes `openNote` when it is non-nil.

---

## S005: Reindex in `NoteEditorWindow` on note change and window close (G3)

**Intent:** Edits made in the detached editor window are never reindexed. Adding an `onChange` for `editorWindowVM.openNote` and an `onDisappear` captures these edits.

**Work:**
- In `NoteEditorWindow.swift`, add `@Environment(SearchIndexService.self) private var search`.
- Add `.onChange(of: editorWindowVM.openNote) { oldNote, _ in if let note = oldNote { search.reindex(note: note) } }` on the `NoteEditor` view in the body. This reindexes the previous note when the user navigates to a different note in the window.
- Add `.onDisappear { if let note = editorWindowVM.openNote { search.reindex(note: note) } }` on the `NoteEditor` view so that edits are captured when the window is closed.

**Done when:** `NoteEditorWindow` reindexes the open note on both note change and window disappear.

---

## S006: Delete from index on Move to Trash in `NoteListEntry` (G4)

**Intent:** Notes moved to trash should no longer be findable in search.

**Work:**
- In `NoteListEntry.swift`, identify every location that calls `takeNoteVM.moveNoteToTrash(...)`. This includes: the swipe-to-trash action, the context menu "Move to Trash" item, and the `noteDeleteRegistry` command closure.
- After each `takeNoteVM.moveNoteToTrash(...)` call, add `search.deleteFromIndex(noteID: note.uuid)`.
- `NoteListEntry` already has access to `@Environment(SearchIndexService.self)` or add it if not present. Verify in the file.

**Done when:** Every `moveNoteToTrash` call in `NoteListEntry` is immediately followed by `search.deleteFromIndex(noteID: note.uuid)`.

---

## S007: Delete from index on Empty Trash in `MainWindow` (G5)

**Intent:** When Empty Trash permanently deletes notes, they must be purged from the FTS index.

**Work:**
- In `MainWindow.swift`, locate the Empty Trash confirmation alert's action closure that calls `takeNoteVM.emptyTrash(modelContext)`.
- Before calling `emptyTrash`, capture the list of note UUIDs from trash: `let trashNoteIDs = takeNoteVM.trashFolder?.notes.map { $0.uuid } ?? []`.
- After calling `takeNoteVM.emptyTrash(modelContext)`, iterate `trashNoteIDs` and call `search.deleteFromIndex(noteID: id)` for each.
- `MainWindow` must have `@Environment(SearchIndexService.self) private var search` — verify it is present or add it.

**Done when:** The Empty Trash action captures and purges all trash note UUIDs from the FTS index.

---

## S008: Update search-system docs

**Intent:** The docs accurately describe when indexing and deletion run, per L17/L18/L19.

**Work:**
- Update `/Users/adam/Development/TakeNote/.ushabti/docs/search-system.md`, specifically the "When Indexing Runs" section, to document all new index paths added in this Phase.
- Add a new "When Index Deletion Runs" section documenting G4 and G5 deletion paths.

**Done when:** `search-system.md` accurately describes all indexing and deletion triggers after this Phase.
