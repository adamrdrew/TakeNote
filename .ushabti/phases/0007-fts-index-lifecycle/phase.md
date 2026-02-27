# Phase 0007: FTS Index Lifecycle Gaps

## Intent

The FTS5 search index does not stay current with all note mutations. Five lifecycle gaps mean the index silently diverges from the live data: notes created outside CloudKit sync are never indexed, edits made before quitting are dropped, edits in the detached editor window are ignored, trashed notes remain searchable, and notes destroyed by Empty Trash are never purged. This Phase plugs all five gaps so the index remains consistent with the notes data at every mutation point.

## Scope

**In scope:**
- G1: Call `search.reindex(note:)` after a note is created in all `addNote` call sites in `NoteList` (text drop and the string created via `takeNoteVM.addNote()`)
- G1: Call `search.reindex(note:)` after `pasteNote()` creates a copy-pasted note in `NoteList`
- G2: Reindex `openNote` when `scenePhase` transitions to `.background` or `.inactive` in the main window scene (in `TakeNoteApp.swift`), so edits are captured on quit or backgrounding
- G3: Add `onChange(of: editorWindowVM.openNote)` in `NoteEditorWindow` to reindex the previous note when the window switches notes, and reindex on `.onDisappear` so edits are captured on window close
- G4: Add a `delete(noteID:)` call on `SearchIndexService` gated by `chatFeatureFlagEnabled`, then call it from `moveNoteToTrash` call sites — because `TakeNoteVM.moveNoteToTrash()` does not have access to `SearchIndexService`, the delete is applied at the `NoteList` call site (swipe-to-trash, context menu trash) by observing the deselection that follows, or by wrapping the call in `NoteListEntry` where the registry command also triggers `noteDeleteRegistry`; the cleanest minimal approach is to add a `deleteFromIndex(noteID:)` method to `SearchIndexService` and call it from the view layer at every trash call site
- G5: Call `search.index.delete(noteID:)` (via a new `SearchIndexService.deleteFromIndex(noteID:)` helper) for every note before deletion in `emptyTrash` — since `TakeNoteVM` cannot access `SearchIndexService`, the `emptyTrash` call site in `MainWindow` must be updated to pass the note UUIDs to the search service before or after calling `takeNoteVM.emptyTrash()`

**Out of scope:**
- Refactoring `TakeNoteVM` to hold a reference to `SearchIndexService`
- Changing the existing deselect-reindex path in `NoteList.onChange(of: takeNoteVM.selectedNotes)` — it remains the primary single-note reindex path
- Changing the bulk reindex path in `AppBootstrapper`
- Any changes to `SearchIndex.swift` schema or FTS logic
- `AppIntents` note creation path (it calls `TakeNoteVM.addNote()` via `AppDependencyManager`; the reindex will be covered once `addNote()` is called and the note is subsequently deselected, or can be added as a follow-up if needed)

## Constraints

- **L07**: All search indexing calls MUST be gated on `chatFeatureFlagEnabled`. `SearchIndexService.reindex(note:)` already enforces this internally; the new `deleteFromIndex(noteID:)` method must do the same.
- **L09**: `TakeNoteVM` is the sole state manager. Do not add `SearchIndexService` as a property on `TakeNoteVM`. Pass `search` at the call site or use `@Environment`.
- **L10**: Permanent deletion only happens in `emptyTrash()`. The index delete for G5 must accompany the `emptyTrash` call, not replace it.
- **Style**: New service methods use `os.Logger` logging; new `SearchIndexService` method follows the existing internal pattern. Keep changes minimal.

## Acceptance criteria

- A note created via New Note button, toolbar, FileCommands, text drop, or copy-paste is present in the FTS index immediately after creation (not only after deselection or next startup).
- A note edited and the app quit (or backgrounded) without deselecting has its latest content reflected in the FTS index on next launch.
- A note edited in a detached `NoteEditorWindow` and the window closed has its latest content reflected in the FTS index after close.
- A note moved to Trash is removed from the FTS index immediately (not found by search after trashing).
- After Empty Trash, no note from the trash remains in the FTS index.
- All indexing paths remain no-ops when `chatFeatureFlagEnabled` is `false`.
- The existing deselect-reindex path in `NoteList` is unchanged.
- Build compiles without warnings or errors.

## Risks / notes

- `NoteEditorWindow` uses an isolated `TakeNoteVM()` instance (L09 exception). The `search` environment is already injected there. The window can read `SearchIndexService` via `@Environment`.
- G2 (quit-mid-edit) is addressed at the `TakeNoteApp` `scenePhase` level, which has access to both `takeNoteVM.openNote` and the `search` service. The `scenePhase` handler already runs a `Task { @MainActor in ... }` block for `.inactive`/`.background` — the reindex call fits there naturally.
- G4 and G5 require a new `deleteFromIndex(noteID:)` method on `SearchIndexService` since `SearchIndex.delete(noteID:)` is not directly exposed through the service layer today.
- The `emptyTrash` path (G5): the note UUIDs must be captured before `takeNoteVM.emptyTrash()` deletes them from the model context. The call site in `MainWindow` handles the confirmation alert; the fix must collect UUIDs before calling `emptyTrash`, then call `search.deleteFromIndex(noteID:)` after.
