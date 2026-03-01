# Phase 0021: Fix Search UX — Auto-Navigate and Clear on Folder Switch

## Intent

Search in TakeNote is globally scoped: when `noteSearchText` is non-empty, `rebuildNoteCache()` searches all non-trash/non-buffer/non-archive notes regardless of which folder is selected. This is correct behavior, but it creates a confusing UX because the sidebar still highlights the user's current folder while showing results from everywhere. Additionally, switching folders while a search is active does not clear the search text, leaving stale results visible.

This Phase makes the global scope of search explicit and self-consistent:

1. **On search submit (Enter/Return):** programmatically navigate to All Notes so the sidebar communicates that results span all notes.
2. **On folder switch:** clear `noteSearchText` so the new folder's contents are shown cleanly — unless the folder switch was itself triggered by the search submit (Change 1), in which case clearing must be suppressed.

A boolean flag `isSearchNavigating` on `TakeNoteVM` coordinates between these two behaviors.

## Scope

**In scope:**
- Add `isSearchNavigating: Bool` property to `TakeNoteVM`
- Add `.onSubmit(of: .search)` modifier to `MainWindow.swift` immediately after `.searchable(text:)`, navigating to `allNotesFolder` when search text is non-empty and setting the coordination flag
- Modify the `.onChange(of: takeNoteVM.selectedContainer)` handler in `NoteList.swift` to conditionally clear `noteSearchText` based on the flag
- Update `.ushabti/docs/view-model.md` and `.ushabti/docs/views.md` to reflect the new flag and behavior

**Out of scope:**
- Changing how `rebuildNoteCache()` works
- Changing the FTS search backend or `SearchIndexService`
- Any macOS-only search changes (the `.onSubmit(of: .search)` modifier works on both platforms; the behavioral fix applies everywhere)
- Any change to `NoteListHeader` display logic

## Constraints

- **L09** — `TakeNoteVM` is the sole app-wide state manager. The new `isSearchNavigating` flag belongs there, not as local view state.
- **L01** — Minimum macOS 26 / iOS 26. No `#available` guards for earlier versions.
- **Style** — Boolean flags describing a transient navigation mode follow the `inXxxMode` convention, but because this flag is a one-shot coordination signal (set immediately before an action, read and reset in a handler), `isSearchNavigating` matches the spirit of the codebase's boolean naming and is the name specified in the prompt. Use it as-is.
- **Style** — `TakeNoteVM` additions use `lowerCamelCase`.
- **L17 / L18 / L19** — Docs must be updated and reconciled before the Phase is complete.

## Acceptance criteria

1. Typing in the search field and pressing Enter/Return causes the sidebar to navigate to All Notes (visible highlight change).
2. After pressing Enter/Return in a non-empty search field from any folder, the search text remains populated in the search bar (it is not cleared).
3. Manually tapping a different folder or system container in the sidebar while search text is non-empty clears the search field.
4. When the user presses Enter/Return in an empty search field, no navigation occurs.
5. The `isSearchNavigating` flag is never left in a `true` state after a container-change cycle completes.
6. All existing search behavior (FTS results, global scope during search, sort/filter) is unchanged.
7. `.ushabti/docs/view-model.md` and `.ushabti/docs/views.md` are updated to document the new flag and behavior.

## Risks / notes

- The `.onChange(of: takeNoteVM.selectedContainer)` handler in `NoteList.swift` currently calls only `rebuildNoteCache()`. After this change it will conditionally clear `noteSearchText` before rebuilding the cache. Order matters: clear first, then rebuild, so the cache reflects the cleared search text when viewing a user-switched folder.
- `isSearchNavigating` is a transient, non-persisted coordination flag. It must not be stored in `UserDefaults` or SwiftData.
- Three independent `TakeNoteVM` instances may exist (main window, editor window, chat window). This flag is only meaningful on the main window instance. The flag on other instances will never be set; this is harmless.
