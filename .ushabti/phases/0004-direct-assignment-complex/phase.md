# Phase 0004: Direct Property Assignment Fixes — Complex Cases

## Intent

Fix two remaining direct property assignment violations (R007, R009) that require more careful handling than the simple swaps in Phase 0003.

**R007 — NoteEditor:** `doMagicFormat()` sets `openNote!.content = result.formattedText` directly after Magic Format completes. More significantly, the `CodeEditor` binding `set:` handler sets `openNote?.content = $0` and `openNote?.updatedDate = Date()` directly on every keystroke. Calling `setContent()` on every keystroke would invoke `WidgetCenter.shared.reloadAllTimelines()` on every keystroke, which is excessive and potentially harmful to performance. The correct fix is two-part: (1) fix `doMagicFormat()` to use `setContent()` since it is a deliberate one-shot mutation, not a continuous keystroke stream; (2) for the `CodeEditor` binding, keep direct assignment for `content` on each keystroke but call `setContent()` — without triggering a redundant widget reload — when the user deselects the note (which already triggers `NoteList.onChange(of: takeNoteVM.selectedNotes)`). On deselection, `setTitle()` is already called; the content is not re-set via `setContent()`. After examining the code, the cleanest approach is to add a `Note.setContentWithoutWidgetReload(_:)` internal method — or to make the CodeEditor binding continue setting `content` and `updatedDate` directly (as it already does, correctly updating `updatedDate`), and accept that the widget reload happens on deselection when `setContent()` would be called anyway. Read the full NoteEditor and NoteList deselection lifecycle before implementing.

**R009 — NoteList.pasteNote():** When the note being pasted is NOT from the buffer (i.e., a copy-paste rather than a cut-paste), a brand new `Note` is constructed and its fields are set by direct assignment before `modelContext.insert(newNote)`. Since this is a new in-memory object not yet tracked by SwiftData, calling `setContent()` and `setTitle()` would each trigger an immediate `WidgetCenter.reloadAllTimelines()` and a separate `updatedDate` update. A cleaner pattern for new-note construction is to set `content`, `title`, and other fields directly before insertion (since no observers are watching an uninserted model object), and call `reloadAllTimelines()` once after insertion and save. Alternatively, a convenience initializer on `Note` that accepts title, content, aiSummary, and other fields could consolidate the construction. Read `Note.init(folder:)` and `pasteNote()` in full before implementing.

## Scope

**In scope:**
- Fix `NoteEditor.doMagicFormat()` to call `openNote!.setContent(result.formattedText)` instead of direct assignment (R007, first location)
- Determine and implement the correct policy for the `CodeEditor` binding `set:` handler — either: (a) keep direct assignment for `content` and `updatedDate` on keystrokes (accepting no widget reload mid-edit, which is fine since deselection triggers reindex and `setTitle()` already), or (b) introduce a mechanism to defer the widget reload; document the decision in the phase notes and in docs
- Fix `NoteList.pasteNote()` to avoid unnecessary individual side-effect calls on new-note construction — either through a batch initializer, a single `reloadAllTimelines()` after save, or a justified use of direct assignment for uninserted objects (R009)
- Update `.ushabti/docs/views.md` to remove the R007 "Known Issue" note and describe the correct behavior

**Out of scope:**
- Changes to R001, R002, R004, R005, R006, R010, R011 (handled in prior phases)
- Adding debounce infrastructure for widget reloads (would be a separate architectural change)
- Modifying the `Note` schema or adding new persisted fields

## Constraints

- Style: Model mutations that need side effects go through the model's mutating methods (style guide)
- Performance: `WidgetCenter.shared.reloadAllTimelines()` should not be called on every keystroke; this is explicitly called out in the style guide ("do not add additional `reloadAllTimelines()` calls without good reason")
- L03: No schema changes are permitted without bumping `ckBootstrapVersionCurrent`; if a new `Note` initializer or method is added, it must not add persisted fields
- L12: `Note.uuid` must not be reassigned; the paste copy path must not touch `uuid`
- L10: Notes are never permanently deleted outside `emptyTrash()`; the paste path creates new notes which is correct

## Acceptance criteria

- `NoteEditor.doMagicFormat()` calls `openNote!.setContent(result.formattedText)` instead of direct assignment
- The `CodeEditor` binding `set:` policy is explicitly decided and documented: either the binding continues with direct assignment (with a documented rationale in a code comment and in docs), or a deferred approach is implemented. In either case, `updatedDate` is correctly maintained on each keystroke as it is today.
- `NoteList.pasteNote()` does not call `setContent()` / `setTitle()` individually on a new in-memory note in a way that triggers redundant side effects; the chosen implementation is described in a code comment
- The project builds successfully
- `.ushabti/docs/views.md` no longer lists R007 as an open known issue; the actual behavior of the CodeEditor binding and `doMagicFormat()` is described accurately

## Risks / notes

- **CodeEditor binding decision:** The current code already sets `openNote?.updatedDate = Date()` directly on every keystroke, so `updatedDate` is not being lost. The only missing side effect is `WidgetCenter.shared.reloadAllTimelines()`. Given that `NoteList.onChange(of: takeNoteVM.selectedNotes)` already calls `note.setTitle()` on deselection (which itself calls `reloadAllTimelines()`), the widget IS eventually updated when the user leaves the note. The strongest argument for keeping direct assignment in the CodeEditor binding is therefore the performance argument: widget reload on every keystroke is clearly wrong. Builder should read both `NoteList.onChange` and `NoteEditor` to confirm the deselection path triggers a widget reload and document the conclusion.

- **pasteNote() new-note construction:** Calling `setContent()` and `setTitle()` on an uninserted SwiftData model object is technically safe (the model is in memory, not yet tracked), but triggers `WidgetCenter.reloadAllTimelines()` twice unnecessarily. Setting properties directly on the uninserted object and calling `reloadAllTimelines()` once after save is semantically equivalent and more efficient. Builder should confirm that `Note.init(folder:)` already calls `reloadAllTimelines()` once, which may mean no additional call is needed from `pasteNote()` at all — only `setTitle` and the various field copies need to happen before `modelContext.insert`.
