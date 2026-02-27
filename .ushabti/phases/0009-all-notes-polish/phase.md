# Phase 0009: All Notes Polish

## Intent

Three small gaps were found during user testing of Phase 0008. This phase closes them: (1) All Notes is sorted into its correct position in the sidebar (below Starred, above Trash); (2) the note count badge on All Notes shows the real count instead of zero; (3) note list entries show the source folder badge when All Notes is the selected container, matching the existing behavior already present for Starred.

## Scope

**In scope:**
- Replace the alphabetical sort on `Sidebar.systemFolders` with an explicit sort-order function so the system folder section renders: Inbox, Starred, All Notes, Trash — in that deterministic order.
- Fix `NoteListHeader.noteCountLabel` so that when the selected container is All Notes it reads the count from the actual note list (`filteredNotes`) rather than `container.notes.count` (which is always zero because no note has All Notes as its folder). The count must exclude Trash and Buffer notes, matching what the note list shows.
- Extend the `NoteListEntry.MetadataRow` condition and the "Go to Note Folder" context-menu guard to include `isAllNotes`, so the source folder name and icon appear for each note when All Notes is selected.
- Update `views.md` to reflect the corrected sidebar sort logic and the All Notes count behavior.

**Out of scope:**
- Any new persisted fields or schema changes.
- Changes to how the note list sources or filters its data.
- Any changes to the All Notes container's creation, reconciliation, or selection behavior.
- Changes to how other system containers (Inbox, Starred, Trash) display counts or folder badges.

## Constraints

- **L03:** No schema changes; no `ckBootstrapVersionCurrent` bump required.
- **L09:** No new `@Observable` state managers.
- **L11:** `canBeDeleted` on system containers is not touched.
- **L16 / L17:** `views.md` must be updated to reflect the sidebar sort change and the All Notes count approach.
- **Style:** Sub-view computed properties on entry types use `UpperCamelCase`. The sort-order function in `Sidebar` is a file-scope or view-scope helper, `lowerCamelCase`. The `MetadataRow` condition extension follows the existing `isTag == true || isStarred == true` boolean-OR pattern.

## Acceptance criteria

1. In the sidebar, system folders appear in the order: Inbox, Starred, All Notes, Trash — regardless of alphabetical naming.
2. When All Notes is selected, `NoteListHeader` shows an accurate count of non-Trash, non-Buffer notes (matching the list count).
3. When All Notes is selected, each note row in the list shows the source folder name and icon badge in `MetadataRow`, identical to the display when Starred is selected.
4. The "Go to Note Folder" context-menu item is present and functional when All Notes is selected.
5. No regressions in how Starred, Inbox, Trash, or user folder note counts or folder badges display.
6. `views.md` is updated to document the sidebar sort order and the All Notes count logic.

## Risks / notes

- `NoteListHeader` does not currently receive `filteredNotes` from `NoteList`. The cleanest approach is to compute the count directly in the header: when `selectedContainer?.isAllNotes == true`, query all notes that are not in Trash or Buffer using the same `@Query var notes: [Note]` pattern already used in `NoteList`, or add an `allNotesCount: Int` computed property to `TakeNoteVM` backed by the same global notes query. The latter keeps count computation out of the header view and avoids an additional `@Query` in the header. Builder should evaluate both and choose the simpler one; either is acceptable as long as the count is accurate and reactive.
- The sidebar sort: the system folder section currently uses `.sorted(by: { $0.name < $1.name })`. A dedicated sort-order helper — e.g., a `systemFolderSortOrder(_ folder: NoteContainer) -> Int` free function or private method — that maps Inbox→0, Starred→1, AllNotes→2, Trash→3, unknown→4 is the correct pattern. No new state is required.
