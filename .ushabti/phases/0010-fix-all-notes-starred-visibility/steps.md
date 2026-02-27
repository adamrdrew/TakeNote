# Steps

## S001: Update folderHasStarredNotes() in NoteList.swift

**Intent:** Fix the function so it correctly detects starred notes when All Notes is the selected container.

**Work:**
- Open `TakeNote/Views/NoteList/NoteList.swift`.
- Replace the existing `folderHasStarredNotes()` implementation with the corrected version that adds an `isAllNotes` branch:

```swift
func folderHasStarredNotes() -> Bool {
    if takeNoteVM.selectedContainer?.isAllNotes == true {
        return sortedNotes.contains { $0.starred }
    }
    return takeNoteVM.selectedContainer?.notes.contains { $0.starred } ?? false
}
```

- No other changes to this file are required.

**Done when:** The function contains the `isAllNotes` branch and falls through to the original logic for all other containers.

## S002: Update views.md to document the All Notes starred-section behavior

**Intent:** Keep the NoteList documentation accurate so future agents understand why `folderHasStarredNotes()` has two branches.

**Work:**
- Open `.ushabti/docs/views.md`.
- In the NoteList section, add a note explaining that `folderHasStarredNotes()` uses `sortedNotes` when `selectedContainer?.isAllNotes == true` (because the All Notes virtual container's `notes` property is always empty), and falls back to `selectedContainer?.notes` for all other containers.
- Place this note near the existing description of starred-note grouping behavior.

**Done when:** The NoteList section of `views.md` documents the two-branch behavior of `folderHasStarredNotes()` and explains why the All Notes case requires a separate path.

## S003: Bump CURRENT_PROJECT_VERSION and MARKETING_VERSION in project.pbxproj

**Intent:** Satisfy L20, which requires Overseer to increment both version fields before any Phase is marked complete.

**Work:**
- Open `TakeNote.xcodeproj/project.pbxproj`.
- Find all four occurrences of `CURRENT_PROJECT_VERSION = 12;` and change each to `CURRENT_PROJECT_VERSION = 13;`.
- Find all four occurrences of `MARKETING_VERSION = 1.1.8;` and change each to `MARKETING_VERSION = 1.1.9;`.

**Done when:** All four `CURRENT_PROJECT_VERSION` entries read `13` and all four `MARKETING_VERSION` entries read `1.1.9` in `project.pbxproj`.
