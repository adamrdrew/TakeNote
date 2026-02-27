# Steps

## S001: Fix direct assignment in NewNoteWithContentIntent

**Intent:** Ensure that setting content and title on a new note via Siri/Shortcuts goes through the model's mutating methods, triggering the correct side effects.

**Work:**
- In `TakeNote/AppIntents/NewNoteWithContentIntent.swift`, inside `perform()`:
  - Replace `note.content = content` with `note.setContent(content)`
  - Replace `note.title = noteTitle` with `note.setTitle(noteTitle)`

**Done when:** The two direct assignments are replaced; no other changes are made to this file.

---

## S002: Fix direct assignment in NoteList.cuttable

**Intent:** Ensure that stashing a note in the buffer folder (cut operation) goes through `setFolder`, triggering `updatedDate` and widget reload.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, inside the `.cuttable(for: NoteIDWrapper.self)` closure:
  - Replace `note.folder = bf` with `note.setFolder(bf)`

**Done when:** The direct `note.folder = bf` assignment is replaced with `note.setFolder(bf)`; no other changes are made to this closure.

---

## S003: Fix direct assignment in MovePopoverContent

**Intent:** Ensure that moving a note via the iOS move popover goes through `setTag`/`setFolder`, triggering `updatedDate` and widget reload.

**Work:**
- In `TakeNote/Views/NoteList/NoteListEntry.swift`, inside `MovePopoverContent.body`, in the `.onChange(of: selectedContainer)` closure:
  - Replace `note.tag = container` with `note.setTag(container)`
  - Replace `note.folder = container` with `note.setFolder(container)`

**Done when:** Both direct assignments are replaced with their mutating-method equivalents.

---

## S004: Update docs to reflect fixes

**Intent:** Keep `.ushabti/docs/` accurate (required by L17/L18/L19).

**Work:**
- In `.ushabti/docs/supporting-systems.md`, find any reference to the direct-assignment pattern in `NewNoteWithContentIntent` and update it to reflect the corrected pattern if such a note exists
- In `.ushabti/docs/views.md`, check whether R010 or R011 are referenced as known issues and update accordingly

**Done when:** Docs do not describe the direct-assignment violations in these three locations as open issues.
