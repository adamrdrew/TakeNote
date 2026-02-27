# Review: Phase 0007 — FTS Index Lifecycle Gaps

## Summary

Phase 0007 plugs five FTS index lifecycle gaps: notes created outside CloudKit sync (G1), edits dropped on quit (G2), edits in the detached editor window (G3), trashed notes remaining searchable (G4), and notes persisting in the index after Empty Trash (G5). All eight steps are implemented, and every acceptance criterion is satisfied. The implementation is clean, minimal, and law-compliant.

## Verified

### S001 — deleteFromIndex(noteID:) on SearchIndexService

`/Users/adam/Development/TakeNote/TakeNote/Library/SearchIndexService.swift` lines 63-67: method is present, returns immediately when `chatFeatureFlagEnabled == false`, logs at debug level with the existing `logger`, and dispatches `Task { index.delete(noteID: noteID) }`. Pattern matches existing `reindex(note:)`. L07 gated. Done when satisfied.

### S002 — Reindex on note creation (addNote path, G1)

- `NoteList.swift` lines 301-303: drop-destination for `String.self` calls `search.reindex(note: newNote)` after `addNote()` and `setContent()`.
- `MainWindow.swift` lines 82-84: toolbar Add Note button calls `search.reindex(note: newNote)` after `addNote()` returns non-nil. `@Environment(SearchIndexService.self) private var search` confirmed present at line 21.
- `FileCommands.swift` lines 48-50: New Note command calls `search?.reindex(note: newNote)` after `addNote()` returns non-nil. `@FocusedValue(SearchIndexService.self) private var search` confirmed at lines 14-15.

AppIntents path is explicitly out of scope per phase.md.

### S003 — Reindex on copy-paste (G1 copy-paste)

`NoteList.swift` line 158: `search.reindex(note: newNote)` called after `modelContext.insert(newNote)` in the copy-paste branch of `pasteNote()`. Done when satisfied.

### S004 — Reindex on scenePhase background/inactive (G2)

`TakeNoteApp.swift` lines 189-195: the `.inactive, .background` case checks `if let openNote = takeNoteVM.openNote` and calls `search.reindex(note: openNote)`. Placed after `SnapshotController.takeSnapshot` within the existing `Task { @MainActor in }` block. Feature-flag gate is enforced internally by `reindex(note:)`. Done when satisfied.

### S005 — Reindex in NoteEditorWindow on note change and window close (G3)

`NoteEditorWindow.swift`:
- Line 18: `@Environment(SearchIndexService.self) private var search` added.
- Lines 58-62: `.onChange(of: editorWindowVM.openNote)` reindexes `oldNote` on note switch.
- Lines 63-66: `.onDisappear` reindexes `editorWindowVM.openNote` on window close.
- `search` environment is injected from `TakeNoteApp.swift` line 209 (`.environment(search)` on `NoteEditorWindow`). Done when satisfied.

### S006 — Delete from index on Move to Trash (G4)

`NoteListEntry.swift`:
- Line 70: `@Environment(SearchIndexService.self) private var search` confirmed present.
- `moveToTrash()` lines 111-112: calls `search.deleteFromIndex(noteID: note.uuid)` immediately after `moveNoteToTrash`.
- `moveSelectedNotesToTrash()` lines 122-123: calls `search.deleteFromIndex(noteID: sn.uuid)` for each note.

All three trash paths — swipe-to-trash (line 353), context menu (line 397 sets `inMoveToTrashMode`, alert at line 550 calls `moveToTrash()`), and `noteDeleteRegistry` (line 507 registers `moveToTrash`) — route through `moveToTrash()`. All covered. Done when satisfied.

### S007 — Delete from index on Empty Trash (G5)

`MainWindow.swift` lines 246-252: before `takeNoteVM.emptyTrash(modelContext)`, captures `let trashNoteIDs = takeNoteVM.trashFolder?.notes.map { $0.uuid } ?? []`. After `emptyTrash`, iterates and calls `search.deleteFromIndex(noteID: noteID)` for each. `@Environment(SearchIndexService.self) private var search` present at line 21 (added in S002). Done when satisfied.

### S008 — search-system.md updated

`/Users/adam/Development/TakeNote/.ushabti/docs/search-system.md`:
- `deleteFromIndex(noteID:)` added to Methods table (line 36).
- All new creation paths added to "When Indexing Runs" (lines 41-48).
- New "When Index Deletion Runs" section added (lines 51-57) documenting G4 single-note, G4 multi-select, and G5 Empty Trash paths.

Docs are accurate and complete. L17, L18, L19 satisfied.

## Law Compliance

- **L01**: `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `MACOSX_DEPLOYMENT_TARGET = 26.0` confirmed. No `#available` guards for earlier versions introduced.
- **L02**: No new `@Model` types introduced.
- **L03**: No schema changes; no version bump required.
- **L04**: No third-party LLM. Not applicable to this phase.
- **L05**: Not applicable to this phase.
- **L06**: Not applicable to this phase.
- **L07**: All new `deleteFromIndex` calls are gated on `chatFeatureFlagEnabled` inside `SearchIndexService.deleteFromIndex`. All new `reindex` calls are gated internally by `SearchIndexService.reindex`. Verified.
- **L08**: No widget code touched.
- **L09**: `SearchIndexService` is accessed via `@Environment` at the call site; not added as a property to `TakeNoteVM`. Correct.
- **L10**: `moveNoteToTrash` is still the only path to move notes to trash; `emptyTrash` is still the only permanent deletion path. Index deletion accompanies but does not replace these calls.
- **L13**: `SearchIndexService.index` remains `SearchIndex` (FTS5). `VectorSearchIndex` not introduced.
- **L15**: `NoteListEntry` `.onAppear`/`.onDisappear` registration pairs are intact and unchanged.
- **L20**: `CURRENT_PROJECT_VERSION` bumped from 9 to 10; `MARKETING_VERSION` bumped from 1.1.5 to 1.1.6. All four occurrences of each updated in `TakeNote.xcodeproj/project.pbxproj`.

## Style Compliance

- New method `deleteFromIndex(noteID:)` uses `os.Logger` at `.debug` level. Matches existing pattern.
- `@Environment(SearchIndexService.self)` access follows the established service injection pattern.
- No new `@Observable` state managers introduced.
- Sub-view computed properties in `NoteListEntry` use `UpperCamelCase` — no regressions.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. Phase 0007 is complete. All acceptance criteria are satisfied, all eight steps are verified, all applicable laws are respected, and documentation is reconciled. Weighed and found true.
