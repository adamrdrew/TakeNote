# Steps

## S001: Fix SearchIndexService logger subsystem typo

**Intent:** Correct the doubled-'m' typo so log messages from `SearchIndexService` appear under the correct subsystem in Console and unified logging.

**Work:**
- In `TakeNote/Library/SearchIndexService.swift` line 30, change `"com.adammdrew.takenote"` to `"com.adamdrew.takenote"`

**Done when:** The `logger` property reads `Logger(subsystem: "com.adamdrew.takenote", category: "SearchIndexService")` with a single 'm'.

---

## S002: Migrate MagicFormatter to @Observable

**Intent:** Align `MagicFormatter` with the project-standard `@Observable` pattern and eliminate `ObservableObject`/`@Published` usage.

**Work:**
- In `TakeNote/Library/MagicFormatter.swift`:
  - Remove `ObservableObject` conformance from the class declaration
  - Add `@Observable` macro to the class declaration (`@MainActor @Observable class MagicFormatter`)
  - Remove `@Published` annotations from `formatterIsBusy` and `sessionCancelled`
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`:
  - Change `@StateObject private var magicFormatter = MagicFormatter()` to `@State private var magicFormatter = MagicFormatter()`
  - Update the `.sheet(isPresented: $magicFormatter.formatterIsBusy)` binding — with `@Observable` + `@State`, this binding syntax works as-is via `@Bindable` or via `Binding` on the state; confirm the binding compiles and works correctly

**Done when:** `MagicFormatter` has no `ObservableObject` conformance and no `@Published` annotations; `NoteEditor` uses `@State`; the project compiles without `ObservableObject`-related warnings.

---

## S003: Replace print() in CommandRegistry

**Intent:** Remove the production `print()` debug trace from `CommandRegistry.runCommand` and replace it with a proper `os.Logger` call.

**Work:**
- In `TakeNote/Library/CommandRegistry.swift`:
  - Add a file-scoped `let logger = Logger(subsystem: "com.adamdrew.takenote", category: "CommandRegistry")` constant
  - Replace `print("CommandRegistry: Running Command with ID: \(id)")` with `logger.debug("Running command with ID: \(id)")`

**Done when:** No `print()` call exists in `CommandRegistry.swift`; a `logger.debug` call is in its place.

---

## S004: Replace print() in SystemFolderReconciler

**Intent:** Remove the production `print()` call from `SystemFolderReconciler.reconcile` and replace it with an `os.Logger` call.

**Work:**
- In `TakeNote/Library/SystemFolderReconciler.swift`:
  - Add `import os` if not already present
  - Add a `let logger = Logger(subsystem: "com.adamdrew.takenote", category: "SystemFolderReconciler")` property
  - Replace `print("System folder duplicate found. Reconciling...")` with `logger.info("System folder duplicate found. Reconciling.")`

**Done when:** No `print()` call exists in `SystemFolderReconciler.swift`; a `logger.info` call is in its place.

---

## S005: Replace print() in NoteLinkManager

**Intent:** Remove the production `print("Created a link")` call from `NoteLinkManager.generateLinksFor`.

**Work:**
- In `TakeNote/Library/NoteLinkManager.swift`:
  - Check if a `logger` property already exists on the class; if not, add one with subsystem `"com.adamdrew.takenote"` and category `"NoteLinkManager"`
  - Replace `print("Created a link")` with `logger.debug("Created a link from \(note.uuid) to \(targetNote.uuid)")`

**Done when:** No `print()` call exists in `NoteLinkManager.swift`.

---

## S006: Replace print() in TakeNoteVM

**Intent:** Remove the production `print()` call from `TakeNoteVM.addNote` and replace it with a `logger` call.

**Work:**
- In `TakeNote/TakeNoteVM.swift` line 157:
  - Check if a `logger` property already exists on `TakeNoteVM`; if not, add one with subsystem `"com.adamdrew.takenote"` and category `"TakeNoteVM"`
  - Replace `print("Adding note failed, no folder selected")` with `logger.warning("addNote called with no selected container")`

**Done when:** No `print()` call exists at line 157 of `TakeNoteVM.swift`.

---

## S007: Replace print() in EditCommands

**Intent:** Remove the production `print("EditMenu.copyMarkdownLink")` trace from `EditCommands`.

**Work:**
- In `TakeNote/Views/Commands/EditCommands.swift` line 124:
  - The `Commands` struct does not hold a long-lived logger instance; add a file-scoped `private let editCommandsLogger = Logger(subsystem: "com.adamdrew.takenote", category: "EditCommands")` constant at the top of the file
  - Replace `print("EditMenu.copyMarkdownLink")` with `editCommandsLogger.debug("copyMarkdownLink command invoked")`

**Done when:** No `print()` call exists in `EditCommands.swift`.

---

## S008: Update docs to reflect hygiene fixes

**Intent:** Keep `.ushabti/docs/` accurate after code changes (required by L17/L18/L19).

**Work:**
- Update `ai-features.md` to remove the note that `MagicFormatter` uses `ObservableObject`/`@Published` and to state it now uses `@Observable`; remove the parenthetical "(R002)" known-debt note
- Update `views.md` to reflect that `NoteEditor` uses `@State` for `magicFormatter`

**Done when:** The docs no longer describe `MagicFormatter` as using `ObservableObject`/`@Published`; the known-issue note in `ai-features.md` is updated or removed.
