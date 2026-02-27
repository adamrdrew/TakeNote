# Phase 0003: Direct Property Assignment Fixes — Simple Cases

## Intent

Fix three style violations where Note model properties are set directly instead of through the provided mutating methods (`setTitle()`, `setContent()`, `setFolder()`, `setTag()`). Direct assignment bypasses `updatedDate` updates and `WidgetCenter.shared.reloadAllTimelines()` calls that are encapsulated in those methods. The three cases in this phase (R005, R010, R011) are unambiguous: in each case, the side effects are desired and there is no performance concern about calling the mutating methods.

R005: `NewNoteWithContentIntent.perform()` sets `note.content` and `note.title` directly on a note that is already saved and has been selected in the UI. This means the title and content changes do not update `updatedDate` or trigger widget reloads, leaving the note sorting and widget display stale.

R010: `NoteList.cuttable` sets `note.folder = bf` (the buffer folder) directly when stashing notes for cut-and-paste. This skips `updatedDate` and the widget reload.

R011: `MovePopoverContent.onChange(of:)` sets `note.tag` and `note.folder` directly when the user moves a note via the popover on iOS. This skips `updatedDate` and the widget reload on every note move.

## Scope

**In scope:**
- Replace `note.content = content` / `note.title = noteTitle` with `note.setContent(content)` / `note.setTitle(noteTitle)` in `NewNoteWithContentIntent.perform()` (R005)
- Replace `note.folder = bf` with `note.setFolder(bf)` in the `NoteList.cuttable` closure (R010)
- Replace `note.tag = container` with `note.setTag(container)` and `note.folder = container` with `note.setFolder(container)` in `MovePopoverContent.onChange(of:)` (R011)
- Update docs to reflect fixes

**Out of scope:**
- R007 and R009 (NoteEditor and NoteList.pasteNote) — those require more nuanced handling and are addressed in Phase 0004
- Any other behavioral changes

## Constraints

- Style: Model mutations with side effects must go through `setTitle(_:)`, `setContent(_:)`, `setFolder(_:)`, `setTag(_:)` (style guide, "SwiftData model mutations go through model methods")
- L14: `NewNoteWithContentIntent` must continue to access `TakeNoteVM` and `ModelContainer` only via `@Dependency(key:)` — this fix does not touch that
- L09: No new state managers may be introduced

## Acceptance criteria

- `NewNoteWithContentIntent.perform()` calls `note.setContent(content)` and `note.setTitle(noteTitle)` instead of direct assignment
- `NoteList.cuttable` calls `note.setFolder(bf)` instead of `note.folder = bf`
- `MovePopoverContent.onChange(of:)` calls `note.setTag(container)` and `note.setFolder(container)` instead of direct assignment
- No direct `note.content =`, `note.title =`, `note.folder =`, or `note.tag =` assignments remain in these three locations
- The project builds successfully

## Risks / notes

- `NewNoteWithContentIntent`: the note is freshly created by `addNote()`, which already calls `modelContext.insert(note)` and `modelContext.save()`. Calling `setTitle` and `setContent` after the save adds two more `WidgetCenter.reloadAllTimelines()` calls (the `Note.init` already called it once, for a total of three). This is acceptable — the intent opens the app anyway, and widget reload is inexpensive. If a future performance concern arises, a batch-set method on `Note` could be added, but that is out of scope here.
- `NoteList.cuttable`: calling `setFolder(bf)` on notes being cut will update `updatedDate` to now. This is actually correct behavior — a cut-pasted note has been moved and its modification date should reflect that.
- `MovePopoverContent`: calling `setTag`/`setFolder` will trigger one `reloadAllTimelines()` per note move. This is the correct behavior.
