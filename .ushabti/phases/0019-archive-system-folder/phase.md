# Phase 0019: Archive System Folder

## Intent

Add an Archive system folder to TakeNote. Archived notes are removed from All Notes, excluded from search indexing, and accessible via a new sidebar entry. Users can archive notes via a swipe action (leading edge, all platforms) and a context menu item (all platforms). The feature follows the existing system folder pattern exactly — same reconciliation, same sidebar placement logic, same creation pattern in `folderInit`.

## Scope

**In scope:**
- `isArchive: Bool` field on `NoteContainer` with `canBeDeleted = false`
- `ckBootstrapVersionCurrent` bump in `TakeNoteApp.swift` (L03)
- `archiveFolder` property on `TakeNoteVM`, `createArchiveFolder()`, `moveNoteToArchive()`
- `canAddNote` and `canRenameSelectedContainer` guards updated to exclude the archive folder
- `folderInit` updated to create the archive folder on startup
- `SystemFolderReconciler.runOnce()` updated to reconcile the archive folder
- `Sidebar.swift` system folders query updated to include `|| folder.isArchive`; user folders query updated to exclude `&& !folder.isArchive`; `systemFolderSortOrder` updated to assign sort order 4 to archive (Trash moves to 3, archive to 4, or archive at 4 after trash at 3)
- `isSystemFolder` computed property on `NoteContainer` updated to include `isArchive`
- `NoteList.swift` `allNotesSource` filter updated to also exclude archived notes; `onChange(of: notes.count)` reindex updated to exclude archived notes
- `AppBootstrapper.swift` both reindex call sites (startup and remote change handler) updated to exclude archived notes
- `NoteListEntry.swift` leading-edge swipe action "Move to Archive" (blue tint, `archivebox` icon), guarded so it does not appear when already in archive or trash; context menu "Move to Archive" item on all platforms, same guard
- Documentation update for `data-models.md`, `view-model.md`, `supporting-systems.md`, and `views.md`

**Out of scope:**
- "Unarchive" swipe action or bulk archive operations
- Any change to search UI or the FTS index schema
- Any change to widget snapshot logic
- Permanent deletion of archived notes (archived notes go to trash first per L10 if the user wants to delete them)

## Constraints

- **L02 / L03:** `isArchive` is a new persisted field on `NoteContainer` — `ckBootstrapVersionCurrent` must be bumped in `TakeNoteApp.swift`.
- **L07:** FTS indexing must remain unconditional as a general rule; the archive exclusion is a data-scoping filter (we simply do not pass archived notes to the indexer), not a feature-flag gate. `reindex(note:)` single-note calls already only fire in contexts where the note is being edited, so no change is needed there — only the bulk `reindexAll` call sites that build their note list from a full fetch need the archive exclusion filter.
- **L09:** All new VM state and methods go into `TakeNoteVM`. No new state manager.
- **L10:** Archive does not bypass trash. Archived notes can still be moved to trash; `emptyTrash` remains the sole permanent deletion path.
- **L11:** Archive folder must have `canBeDeleted = false` and must be reconciled in `SystemFolderReconciler.runOnce()`.
- **L15:** The archive swipe action does not use `CommandRegistry` (swipe actions do not route through the menu bar). No new registry is needed.
- **Style:** New `NoteContainer` flag follows the existing `internal var isXxx: Bool = false` property declaration style. Sort order constant for Archive is 4 (Trash moves to 3, Archive to 4 — they were previously at 3 and beyond, so Trash stays at 3 and Archive is appended). New VM property is `archiveFolder: NoteContainer?`. New VM methods follow the `createXxxFolder` and `moveNoteTo` naming conventions.

## Acceptance criteria

1. A new "Archive" system folder appears in the sidebar below Trash, with the `archivebox` SF Symbol, in the system folders section.
2. The Archive folder is created automatically on first launch (via `folderInit`) and is non-deletable and non-renameable.
3. On any platform, right-swiping a note list entry shows a blue "Archive" action that moves the note to the archive folder. The action does not appear when the note is already in the archive or trash folder.
4. On all platforms, the note list entry context menu includes a "Move to Archive" option with the same guard (not shown in archive or trash).
5. Archived notes do not appear in All Notes view.
6. Archived notes are not included in bulk search reindex operations (startup reindex and CloudKit remote-change reindex).
7. The Archive folder appears in the sidebar's system folders section, sorted after Trash.
8. `ckBootstrapVersionCurrent` is bumped in `TakeNoteApp.swift`.
9. The regular user folders list in the sidebar does not include the Archive folder.
10. `canAddNote` returns `false` when the Archive folder is selected. `canRenameSelectedContainer` returns `false` for the Archive folder.
11. `SystemFolderReconciler` reconciles the Archive folder (merges CloudKit duplicates).
12. All modified documented systems have their `.ushabti/docs/` files updated.

## Risks / notes

- The leading-edge swipe action on `NoteListEntry` is currently iOS-only (wrapped in `#if os(iOS)`). The Vizier's analysis says the archive swipe should work on all platforms including macOS (two-finger swipe). On macOS, `.swipeActions` is supported in `List` rows. The existing trailing-edge swipe is not platform-guarded — it applies on both platforms. The archive leading-edge swipe should follow the same unguarded pattern. The existing iOS-only leading swipe (Move popover) should remain iOS-only inside its own `#if os(iOS)` block. The new archive swipe sits outside that block, applying to both platforms.
- `getColor()` on `NoteContainer` returns `.takeNotePink` for `isSystemFolder`. Since `isArchive` is included in `isSystemFolder` after this change, the archive folder will render in the standard system folder pink automatically — no additional color handling needed.
- The `onChange(of: notes.count)` reindex in `NoteList` currently passes all notes from `@Query() var notes`. After this change it must filter out archived notes before passing to `reindexAll`. This mirrors the same filter applied in `AppBootstrapper`.
