# Phase 0008: All Notes Container

## Intent

Add an "All Notes" system container that appears in the Sidebar alongside Inbox, Trash, and Starred. When selected, it shows every non-trashed, non-buffered note from all folders and tags in a single unified list. The feature follows the exact same patterns used by existing system containers: a new boolean flag on `NoteContainer`, creation and initialization in `TakeNoteVM.folderInit`, reconciliation in `SystemFolderReconciler`, a reference property on `TakeNoteVM`, and inclusion in every predicate and guard that discriminates system containers from user folders. A schema version bump is required.

## Scope

**In scope:**
- New `isAllNotes: Bool = false` persisted field on `NoteContainer` (schema bump required)
- `isSystemFolder` updated to include `isAllNotes`
- `createAllNotesFolder(_:)` method on `TakeNoteVM`; `folderInit` calls it
- `allNotesFolder: NoteContainer?` reference property on `TakeNoteVM`
- `canAddNote` blocked when All Notes is selected
- `canRenameSelectedContainer` blocked when All Notes is selected
- `SystemFolderReconciler.runOnce()` reconciles the new container; `TakeNoteVM.allNotesFolder` updated after reconciliation
- `Sidebar.systemFolders` `@Query` predicate includes `isAllNotes`
- `Sidebar.folders` `@Query` predicate excludes `isAllNotes`
- `FolderList` guard excludes `isAllNotes`
- `NoteList.filteredNotes` provides a cross-container note list when All Notes is selected (using the existing `@Query var notes: [Note]` as the source, filtered to exclude Trash and Buffer notes)
- `NoteListHeader.folderSymbol` falls through to `container.symbol` correctly (no change needed, verified)
- SF Symbol `text.pad.header` for the All Notes container
- Static name constant `allNotesFolderName = "All Notes"` on `TakeNoteVM`
- `ckBootstrapVersionCurrent` bumped in `TakeNoteApp.swift`
- Documentation updated: `data-models.md`, `view-model.md`, `supporting-systems.md`

**Out of scope:**
- Changing the `NoteContainer` data model beyond the single new `isAllNotes` boolean
- Adding new relationship arrays to `NoteContainer` or `Note`
- Changes to how any other system folder works
- Search within All Notes (the existing note list search bar works as-is)
- Widget support for All Notes

## Constraints

- **L02:** No new `@Model` types. The `isAllNotes` field is added to the existing `NoteContainer` model only.
- **L03:** Schema change (new persisted field on `NoteContainer`) requires bumping `ckBootstrapVersionCurrent` in `TakeNoteApp.swift`. The `// Hey! // Hey you!` reminder comment in `NoteContainer.swift` must be respected.
- **L09:** No new `@Observable` state managers. `allNotesFolder` is a simple property added to the existing `TakeNoteVM`.
- **L11:** The All Notes container must have `canBeDeleted = false` at all times. `SystemFolderReconciler.runOnce()` must be extended to reconcile it.
- **Style:** New `isAllNotes` field follows the same `internal var isX: Bool = false` pattern as `isTrash`, `isInbox`, `isStarred`, `isBuffer`. `createAllNotesFolder` follows the same guard-on-nil and error-pattern as the other `createX` methods. Sub-view computed properties use `UpperCamelCase`.

## Acceptance criteria

1. The All Notes entry appears in the Sidebar system folders section with the `text.pad.header` SF Symbol and TakeNote pink color.
2. Selecting All Notes displays all notes from all folders and tags, excluding notes in Trash and Buffer.
3. The search bar in the note list filters the All Notes view correctly.
4. The "Add Note" toolbar button is disabled when All Notes is selected.
5. All Notes cannot be renamed (the inline rename and the Rename menu command are both disabled).
6. All Notes cannot be deleted (no delete option appears in context menu or menu bar).
7. `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` is incremented by 1.
8. `FolderList` does not display the All Notes container in the user folder section.
9. `SystemFolderReconciler` reconciles All Notes duplicates created by CloudKit sync.
10. The `NoteContainer.isSystemFolder` computed property returns `true` for the All Notes container.
11. Docs for `data-models.md`, `view-model.md`, and `supporting-systems.md` are updated to reflect the new container.

## Risks / notes

- The `NoteContainer.notes` computed property routes through `folderNotes`, `starredNotes`, or `tagNotes` based on flags. The All Notes container's own `folderNotes` array will always be empty because no note has its `folder` set to the All Notes container. The cross-container note list must be built in `NoteList.filteredNotes` using the view-level `@Query var notes: [Note]` source, filtered to exclude notes whose folder is Trash or Buffer. This is the correct layering: the model stays clean, the view assembles the virtual list.
- The `getSystemImageName()` method uses explicit checks for `isTrash` and `isInbox` before falling through to `symbol`. The All Notes container will fall through to `symbol` (set to `text.pad.header`), which is correct behavior — no change to that method is needed.
- `getColor()` returns `.takeNotePink` for any `isSystemFolder` container, which will include All Notes after the `isSystemFolder` update.
- On iOS phone, `folderInit` does not set a default `selectedContainer`. The All Notes container does not change this behavior.
