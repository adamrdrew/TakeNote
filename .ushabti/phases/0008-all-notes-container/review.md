# Review: Phase 0008 — All Notes Container

## Summary

All seven steps are implemented correctly. The All Notes system container follows the established pattern for system folders throughout the codebase. No law violations were found. Documentation is reconciled. Build version bumped per L20.

## Verified

### S001 — isAllNotes field and isSystemFolder update
- `NoteContainer.swift` contains `internal var isAllNotes: Bool = false` positioned after `isBuffer`, matching the established `isX: Bool = false` pattern.
- `isSystemFolder` correctly reads `isTrash || isInbox || isStarred || isAllNotes`. The prior implementation on master was `isTrash || isInbox || isStarred`; `isBuffer` was already excluded by design, and the new implementation maintains that.
- The `// Hey! // Hey you!` schema-change reminder comment is present at the top of the file.

### S002 — ckBootstrapVersionCurrent bump (L03)
- `TakeNoteApp.swift` line 14: `private let ckBootstrapVersionCurrent = 9`. Bumped from 8 to 9 as required.

### S003 — allNotesFolder property and createAllNotesFolder method
- `static let allNotesFolderName = "All Notes"` present alongside `inboxFolderName` and `trashFolderName`.
- `var allNotesFolder: NoteContainer?` present alongside the other system folder references.
- `createAllNotesFolder(_:)` correctly guards on `self.allNotesFolder != nil`, creates the container with `canBeDeleted: false`, sets `isAllNotes = true` via direct property assignment (same pattern as `createBufferFolder`), inserts, saves, assigns.
- `folderInit` calls `createAllNotesFolder(modelContext)` as the fifth creation call.
- `canAddNote` checks `selectedContainer?.isAllNotes == false`.
- `canRenameSelectedContainer` checks `sc.isAllNotes` in the guard.

### S004 — SystemFolderReconciler extended for All Notes
- `runOnce()` has `let allNotes = try reconcile(match: #Predicate { $0.isAllNotes })`.
- `vm.allNotesFolder = allNotes ?? fetchSingle(#Predicate { $0.isAllNotes })` follows the same pattern as the other four system folder assignments.
- The generic `reconcile()` and `chooseCanonical()` methods require no modification — they correctly operate on the new container via the predicate.

### S005 — Sidebar queries and FolderList guard
- `Sidebar.folders` `@Query` predicate excludes `isAllNotes`: `!folder.isTag && !folder.isTrash && !folder.isInbox && !folder.isBuffer && !folder.isAllNotes`.
- `Sidebar.systemFolders` `@Query` predicate includes `isAllNotes`: `folder.isTrash || folder.isInbox || folder.isStarred || folder.isAllNotes`.
- `FolderList` guard includes `folder.isAllNotes` in the exclusion check: `folder.isBuffer || folder.isInbox || folder.isTag || folder.isTrash || folder.isStarred || folder.isAllNotes`.

### S006 — Cross-container note list in NoteList
- `filteredNotes` has a branch for `takeNoteVM.selectedContainer?.isAllNotes == true`.
- The All Notes branch filters from `notes` (the `@Query` result that fetches all notes) excluding `folder?.isTrash != true && folder?.isBuffer != true`.
- The search text filter is applied identically to the existing branch.
- The existing branch for other containers is unchanged.

### S007 — Documentation reconciled
- `data-models.md`: `isAllNotes` field added to NoteContainer fields table with accurate description. System Containers table includes All Notes row with correct flag values (`isAllNotes: true`, `canBeDeleted: false`). `isSystemFolder` description updated to include All Notes.
- `view-model.md`: `allNotesFolder` added to System Folder References table. `allNotesFolderName` constant added. `createAllNotesFolder(_:)` added to System Folder Creation list. `canAddNote` and `canRenameSelectedContainer` descriptions updated to reflect All Notes blocking.
- `supporting-systems.md`: `runOnce()` description updated to mention "five system folder types (Inbox, Trash, Buffer, Starred, All Notes)" and `allNotesFolder` in the post-reconciliation update list.

### Acceptance Criteria
1. All Notes appears in Sidebar system folders section with `text.pad.header` symbol — confirmed via `systemFolders` `@Query` predicate including `isAllNotes` and `symbol: "text.pad.header"` set in `createAllNotesFolder`.
2. Shows all notes excluding Trash and Buffer — confirmed via `filteredNotes` All Notes branch.
3. Search bar filters All Notes view correctly — confirmed via `noteSearchText` filter applied in the All Notes branch.
4. Add Note disabled when All Notes selected — confirmed via `canAddNote` check.
5. All Notes cannot be renamed — confirmed via `canRenameSelectedContainer` blocking `sc.isAllNotes`.
6. All Notes cannot be deleted — confirmed via `canBeDeleted: false` and `isSystemFolder: true` (which also affects `getColor()` returning pink consistently).
7. `ckBootstrapVersionCurrent` incremented by 1 (8 → 9) — confirmed.
8. `FolderList` does not display All Notes — confirmed via guard.
9. `SystemFolderReconciler` reconciles All Notes duplicates — confirmed.
10. `isSystemFolder` returns `true` for All Notes — confirmed.
11. Docs updated — confirmed, all three files reconciled.

### Laws Checked
- **L02:** No new `@Model` types. `isAllNotes` added to existing `NoteContainer` only.
- **L03:** `ckBootstrapVersionCurrent` bumped from 8 to 9 with new persisted field.
- **L09:** No new `@Observable` state managers. `allNotesFolder` is a simple property on existing `TakeNoteVM`.
- **L11:** `canBeDeleted = false` set. `SystemFolderReconciler.runOnce()` extended. No code sets `canBeDeleted = true` on the new container.
- **L15:** No new `List` items register commands without unregistering — not applicable to this change.
- **L17/L18/L19:** Docs reconciled in all three affected files.
- **L20:** `CURRENT_PROJECT_VERSION` bumped 10 → 11. `MARKETING_VERSION` bumped 1.1.6 → 1.1.7. All four occurrences of each field updated.

All other laws not touched by this phase were not disturbed.

### Style
- `isAllNotes` field uses `internal var isX: Bool = false` — matches established pattern.
- `createAllNotesFolder` follows same guard-on-nil and error-display pattern as other `createX` methods.
- `allNotesFolderName` is a `static let lowerCamelCase` constant.
- `os.Logger` used in `SystemFolderReconciler` — no `print()` introduced.
- No `UpperCamelCase` sub-view property violations.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. The phase is complete. Weighed and found true.

Version bumped: `CURRENT_PROJECT_VERSION` 10 → 11, `MARKETING_VERSION` 1.1.6 → 1.1.7.
