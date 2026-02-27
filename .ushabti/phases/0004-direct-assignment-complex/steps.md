# Steps

## S001: Read NoteEditor and NoteList deselection lifecycle

**Intent:** Understand the full data flow before making any code changes, to ensure the CodeEditor binding decision is correct and the pasteNote fix is sound.

**Work:**
- Read `TakeNote/Views/NoteEditor/NoteEditor.swift` in full, paying attention to the `doMagicFormat()` function and the `CodeEditor` binding `set:` handler
- Read `TakeNote/Views/NoteList/NoteList.swift` in full, paying attention to `NoteList.onChange(of: takeNoteVM.selectedNotes)` and `pasteNote()`
- Read `TakeNote/Models/Note.swift` in full, paying attention to `Note.init(folder:)`, `setContent()`, `setTitle()`, and `setFolder()`
- Confirm whether the deselection path (`NoteList.onChange`) triggers a widget reload (it does if `setTitle()` is called, since `setTitle()` calls `reloadAllTimelines()`)
- Confirm whether `Note.init(folder:)` calls `reloadAllTimelines()` (it does)

**Done when:** Builder has confirmed the deselection path and has a clear plan for the CodeEditor binding and pasteNote decisions.

---

## S002: Fix doMagicFormat() direct assignment

**Intent:** Ensure that applying Magic Format output to the note goes through `setContent()`, so `updatedDate` and widget reload fire correctly on this deliberate one-shot mutation.

**Work:**
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`, in `doMagicFormat()`:
  - Replace `openNote!.content = result.formattedText` with `openNote!.setContent(result.formattedText)`

**Done when:** `doMagicFormat()` uses `setContent()` for the final content assignment; the rest of the function is unchanged.

---

## S003: Decide and document the CodeEditor binding policy

**Intent:** Make an explicit, documented decision about the CodeEditor binding `set:` handler, rather than leaving it as an undocumented deviation.

**Work:**
- Based on the analysis from S001, decide: keep direct assignment with documented rationale, or implement a deferred approach
- **Recommended approach (justified by deselection lifecycle analysis):** Keep direct assignment for `content` and `updatedDate` in the CodeEditor binding `set:` handler. Add a code comment explaining that: (a) `updatedDate` is maintained correctly, (b) `WidgetCenter.reloadAllTimelines()` is intentionally deferred to note deselection to avoid per-keystroke widget reload, (c) the deselection path in `NoteList.onChange` already triggers `setTitle()` which calls `reloadAllTimelines()`
- The comment should be concise (3-5 lines) and placed immediately above or inside the binding's `set:` closure

**Done when:** The CodeEditor binding `set:` handler has an explanatory comment; no behavioral changes are made to the binding itself.

---

## S004: Fix pasteNote() direct property assignment

**Intent:** Resolve the direct property assignment pattern on a new note during copy-paste, ensuring the note is constructed correctly without unnecessary redundant side effects.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, in `pasteNote()`, in the copy-paste branch (where `note.folder != takeNoteVM.bufferFolder`):
  - The new note is created with `Note(folder: nc)`. The `init` already calls `reloadAllTimelines()`.
  - Fields like `content`, `title`, `aiSummary`, `createdDate`, `updatedDate`, `starred`, `contentHash`, `aiSummaryIsGenerating` are then set directly before `modelContext.insert(newNote)`
  - Since the object is not yet inserted into SwiftData, calling `setContent()` / `setTitle()` at this point would call `reloadAllTimelines()` a second and third time needlessly
  - The correct fix: keep direct field assignment for the uninserted note object (this is justified for a new in-memory object), but add a code comment explaining this decision explicitly, noting that `Note.init` has already called `reloadAllTimelines()` and calling `setContent`/`setTitle` on an uninserted object would redundantly repeat it
  - Do NOT change the field-setting code itself (it is correct); only add the explanatory comment

**Done when:** A code comment in `pasteNote()` explains why direct assignment is used for the copy branch of new-note construction, and no behavioral changes are made.

---

## S005: Update views.md to reflect fixes

**Intent:** Remove the open R007 known-issue note from docs and describe the current correct behavior (required by L17/L18/L19).

**Work:**
- In `.ushabti/docs/views.md`, find the "Known Issue: Direct Content Mutation (R007)" block under the NoteEditor section
- Replace it with an accurate description of the current state:
  - `doMagicFormat()` now calls `setContent()`, correctly triggering side effects
  - The CodeEditor binding uses direct assignment by design for performance (no per-keystroke widget reload); `updatedDate` is maintained correctly; widget reload fires on deselection via the `NoteList.onChange` path
  - Note that `pasteNote()` uses direct assignment for new uninserted note objects by design; a comment in the code explains this

**Done when:** The R007 known-issue note is removed; the NoteEditor and NoteList docs accurately describe the current behavior.
