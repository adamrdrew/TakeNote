# Phase 0010: Fix All Notes Starred Note Visibility

## Intent

Starred notes are invisible when the "All Notes" container is selected in the sidebar. The "Starred" section header never appears, and because starred notes are excluded from the "Notes" section by design, they are entirely absent from the list.

The root cause is `folderHasStarredNotes()` in `NoteList.swift`. It reads `takeNoteVM.selectedContainer?.notes` to determine whether a starred section should render. For regular folders and the Starred container this works, but the All Notes container is a virtual container — its `NoteContainer.notes` computed property always returns an empty array. The function therefore always returns `false` for All Notes, suppressing the Starred section unconditionally.

`filteredNotes` already handles the All Notes case correctly by querying the raw `@Query() var notes` directly. `folderHasStarredNotes()` needs the same branch.

The fix adds an `isAllNotes` guard to `folderHasStarredNotes()` so it checks `sortedNotes` (the already-computed, filtered, sorted array) when All Notes is selected, and falls back to the existing `selectedContainer?.notes` path for all other containers. The NoteList documentation in `views.md` must also be updated to describe this behavior.

## Scope

**In scope:**
- Adding the `isAllNotes` branch to `folderHasStarredNotes()` in `NoteList.swift`
- Updating the NoteList section of `.ushabti/docs/views.md` to document the All Notes starred-section logic

**Out of scope:**
- Changes to data models (`Note`, `NoteContainer`, `NoteLink`)
- Changes to `TakeNoteVM` or any view model
- Changes to `filteredNotes` or `sortedNotes`
- Changes to any file other than `NoteList.swift` and `views.md`

## Constraints

- **L17**: When code changes affect a documented system, Builder must update the relevant docs file and include it in the `touched` list.
- **L18 / L19**: Docs must be reconciled before Overseer may mark the Phase complete.
- **Style**: Read operations on notes use the existing computed properties (`sortedNotes`). No direct property writes bypassing model mutating methods are introduced; this change is read-only.

## Acceptance criteria

1. When "All Notes" is selected and at least one note is starred, a "Starred" section appears at the top of the list containing all starred notes.
2. When "All Notes" is selected and no notes are starred, only the "Notes" section appears (unstarred notes are unaffected).
3. When "All Notes" is selected and every note is starred, the "Notes" section does not appear.
4. When a regular folder, the Starred container, a tag, or Trash is selected, the existing sectioning behavior is unchanged.
5. The fix does not introduce direct property writes that bypass model mutating methods.
6. `.ushabti/docs/views.md` accurately describes the All Notes path in `folderHasStarredNotes()`.

## Risks / notes

This is a single-function, single-file logic change. The corrected function reuses `sortedNotes`, which is already derived from `filteredNotes` (which already handles the All Notes virtual container). There is no risk of introducing a new data path or inconsistency.
