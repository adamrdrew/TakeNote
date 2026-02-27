# Steps

## S001: Fix sidebar system folder ordering

**Intent:** Ensure the sidebar system folder section renders Inbox, Starred, All Notes, Trash in that deterministic order regardless of how SwiftData returns them or how their names sort alphabetically.

**Work:**
- In `Sidebar.swift`, replace the `.sorted(by: { $0.name < $1.name })` call on `systemFolders` with a sort that uses an explicit priority mapping: Inbox→0, Starred→1, AllNotes→2, Trash→3, unknown→4.
- Implement a private helper (a file-scope function or computed property) `systemFolderSortOrder(_ folder: NoteContainer) -> Int` that returns the priority for each known system folder type.
- Apply this sort in the `ForEach` over `systemFolders`.

**Done when:** Running the app shows sidebar system folders in the order Inbox, Starred, All Notes, Trash. No other system folder behavior changes.

---

## S002: Fix All Notes note count in NoteListHeader

**Intent:** Show an accurate, reactive note count when All Notes is selected, instead of always showing zero (which occurs because the All Notes container's own `folderNotes` relationship is always empty).

**Work:**
- Determine the appropriate location for count computation. Preferred approach: add a computed property `allNotesCount: Int` to `TakeNoteVM` that returns the count of all notes excluding Trash and Buffer notes. Because `TakeNoteVM` does not hold a `@Query`, Builder should evaluate whether a dedicated count property can be expressed using the existing `@Query` data available in `NoteList` or whether a separate `@Query` in `NoteListHeader` is simpler.
- If a `@Query` approach is chosen for `NoteListHeader`: add `@Query() var allNotes: [Note]` and compute the count from it when `selectedContainer?.isAllNotes == true`, falling back to `container.notes.count` otherwise.
- Update `NoteListHeader.noteCountLabel` to use the correct count source when `selectedContainer?.isAllNotes == true`.
- The count must match the list count: non-Trash, non-Buffer notes.

**Done when:** When All Notes is selected, the header shows the accurate count of non-Trash, non-Buffer notes. When any other folder is selected, the header count is unchanged.

---

## S003: Show source folder badge in NoteListEntry when All Notes is selected

**Intent:** Enable the existing source-folder display code in `NoteListEntry.MetadataRow` for All Notes, matching the behavior already present for Starred.

**Work:**
- In `NoteListEntry.swift`, locate the `MetadataRow` computed property.
- In the `Group` block, find the condition `if takeNoteVM.selectedContainer?.isTag == true || takeNoteVM.selectedContainer?.isStarred == true`. Add `|| takeNoteVM.selectedContainer?.isAllNotes == true` to this condition.
- Find the "Go to Note Folder" context-menu button, which is currently guarded by `takeNoteVM.selectedContainer?.isTag == true || takeNoteVM.selectedContainer?.isStarred == true`. Add `|| takeNoteVM.selectedContainer?.isAllNotes == true` to that guard as well.

**Done when:** When All Notes is selected, each note row shows the source folder name and icon in the metadata row. The "Go to Note Folder" context menu item appears and navigates to the note's folder. No change in behavior when viewing Starred, a tag, or any user folder.

---

## S004: Update views.md documentation

**Intent:** Keep the documentation accurate per L17 and L19.

**Work:**
- In `.ushabti/docs/views.md`, update the Sidebar section to describe the explicit sort-order function used for system folders (replacing the alphabetical sort description).
- Update the NoteListHeader section to document that when All Notes is selected, the note count is sourced from a separate query (not `container.notes.count`) to correctly count non-Trash, non-Buffer notes.
- Update the NoteListEntry section to note that `MetadataRow` shows the source folder badge when `selectedContainer` is a tag, Starred, or All Notes.

**Done when:** `views.md` accurately reflects the sidebar sort logic, the All Notes note count source, and the updated `MetadataRow` condition. No other documentation files require changes for this phase.
