# Review: Phase 0019 — Archive System Folder

## Summary

Phase 0019 implements the Archive system folder end-to-end. All twelve acceptance criteria are met. All eight steps are verified. No law violations were found. Documentation is reconciled. The project builds successfully on iOS Simulator (iPhone 17 Pro) per the user-confirmed build report. Two post-builder fixes (swipe action block merge, MainWindow.swift revert) were correctly scoped and do not introduce defects. Version bumped by Overseer per L20.

## Verified

**S001 — isArchive field and schema version bump**
- `NoteContainer.swift` line 37: `internal var isArchive: Bool = false` present, following the exact pattern of existing boolean flags.
- `isSystemFolder` at line 47: `isTrash || isInbox || isStarred || isAllNotes || isArchive` — archive correctly included.
- `TakeNoteApp.swift` line 14: `ckBootstrapVersionCurrent = 11` (was 10). L03 satisfied.

**S002 — TakeNoteVM archive methods**
- `archiveFolderName = "Archive"` static constant present (line 29).
- `archiveFolder: NoteContainer?` property present (line 87).
- `createArchiveFolder(_:)` idempotent, creates with `canBeDeleted: false`, `symbol: "archivebox"`, sets `isArchive = true` (lines 307-327).
- `moveNoteToArchive(_:modelContext:)` guards on `archiveFolder` non-nil, uses `note.setFolder(archive)`, saves (lines 329-342).
- `canAddNote` (lines 102-108): returns false for `isArchive`. Correct.
- `canRenameSelectedContainer` (lines 110-116): returns false for `isArchive`. Correct.
- `folderInit` (line 398): calls `createArchiveFolder(modelContext)`. Correct.

**S003 — SystemFolderReconciler**
- `runOnce()` (lines 34, 43): archive reconciled and `vm.archiveFolder` assigned. Six types total. L11 satisfied.

**S004 — Sidebar queries and sort order**
- `systemFolders` query includes `|| folder.isArchive` (line 113).
- `folders` query excludes `&& !folder.isArchive` (line 107).
- `systemFolderSortOrder` returns 4 for Archive (line 90), 5 for unknown fallback (line 91). Inbox=0, Starred=1, AllNotes=2, Trash=3, Archive=4. Deterministic order.

**S005 — AppBootstrapper reindex exclusion**
- Remote change handler (line 151): `.filter { $0.folder?.isArchive != true }` applied before `reindexAll`. Correct.
- Startup reindex (line 178): same filter applied. Both call sites covered.

**S006 — NoteList archive exclusion**
- `allNotesSource` (line 74): `$0.folder?.isArchive != true` added. All Notes view correctly excludes archived notes.
- `onChange(of: notes.count)` (line 338): `.filter { $0.folder?.isArchive != true }` applied. Correct.

**S007 — NoteListEntry swipe action and context menu**
- `archiveNote()` (lines 150-153): calls `moveNoteToArchive` then `search.deleteFromIndex`. Correct.
- Single `.swipeActions(edge: .leading)` block (lines 371-383): Archive button shown when `isArchive != true && isTrash != true`, blue tint. Move popover iOS-only inside the same block. The post-builder merge of two separate `.swipeActions(edge: .leading)` blocks into one is the correct fix — SwiftUI replaces swipe actions on the same edge, so both Archive and Move must be in one block.
- Context menu (lines 407-411): "Move to Archive" shown with same guard. Correct.

**S008 — Documentation**
- `data-models.md`: `isArchive` field documented in NoteContainer fields table with correct description; `isSystemFolder` description updated; System Containers table includes Archive row with correct flag values and `canBeDeleted = false`.
- `view-model.md`: `archiveFolder` in system folder references table; `archiveFolderName` constant documented; `createArchiveFolder` and `moveNoteToArchive` methods documented; `canAddNote` and `canRenameSelectedContainer` descriptions updated to include archive.
- `supporting-systems.md`: `runOnce()` description updated to "six system folder types"; both reindex call sites documented as filtering `isArchive`; startup reindex exclusion documented.
- `views.md`: Sidebar section reflects new queries and sort order; NoteList section documents archive exclusion in `allNotesSource` and `onChange` reindex; NoteListEntry section documents archive swipe (all platforms) and context menu item.

**Laws verification**
- L01: No `#available` checks below iOS 26 / macOS 26 introduced. Deployment targets unchanged.
- L02: No new `@Model` types. `isArchive` is a field on existing `NoteContainer`.
- L03: `ckBootstrapVersionCurrent` bumped from 10 to 11. Compliant.
- L07: FTS indexing unconditional; archive exclusion is a data-scoping filter on the note list passed to `reindexAll`, not a feature-flag gate.
- L09: All new state (`archiveFolder`, `archiveFolderName`, `createArchiveFolder`, `moveNoteToArchive`) added to `TakeNoteVM`.
- L10: Archive does not bypass trash. `emptyTrash` remains sole permanent deletion path.
- L11: Archive `canBeDeleted = false`. Reconciled in `SystemFolderReconciler.runOnce()`.
- L15: Archive swipe action uses no `CommandRegistry` (not menu-bar-routed). No registration/unregistration required.
- L17/L18/L19: All four affected docs files updated and accurate.
- L20: `CURRENT_PROJECT_VERSION` bumped from 21 to 22; `MARKETING_VERSION` bumped from 1.1.17 to 1.1.18. All four occurrences of each field confirmed updated by Overseer.

**Style verification**
- New `isArchive` flag follows `internal var isXxx: Bool = false` pattern.
- `archiveFolderName` is `static let lowerCamelCase` on `TakeNoteVM`.
- `archiveFolder` property is `lowerCamelCase`.
- `createArchiveFolder` and `moveNoteToArchive` follow established naming conventions.
- `archiveNote()` in `NoteListEntry` is `lowerCamelCase`.

**Post-builder fix review**
- Swipe action merge: Correct. Two `.swipeActions(edge: .leading)` blocks were a SwiftUI defect where the second block silently replaced the first. The merged block preserves both behaviors. No other changes introduced.
- MainWindow.swift revert: Correct. The unrelated deletion of an iOS chat popover button was out-of-scope and appropriately reverted.

## Issues

None detected.

## Required follow-ups

None.

## Decision

GREEN. Phase 0019 is complete. All acceptance criteria are met, all laws are satisfied, documentation is reconciled, and the version has been incremented to build 22 / 1.1.18. Weighed and found true.

Recommend handing off to Ushabti Scribe for the next Phase.
