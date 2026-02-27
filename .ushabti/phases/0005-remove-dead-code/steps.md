# Steps

## S001: Delete VectorSearchIndex.swift and EmbeddingProvider.swift

**Intent:** Remove the two files that implement the dead vector search subsystem. These are the largest and most structurally significant deletions; doing them first establishes that the build compiles without them before touching anything else.

**Work:**
- Delete `TakeNote/Library/VectorSearchIndex.swift`
- Delete `TakeNote/Library/EmbeddingProvider.swift`
- Confirm `SearchIndexService.swift` still references `SearchIndex` (not `VectorSearchIndex`) and that no other file imports or references the deleted types

**Done when:** Both files are absent from the repository and the project compiles without errors.

---

## S002: Delete NoteLabelBadge.swift and HistoryPanel.swift

**Intent:** Remove the two dead SwiftUI view files. `NoteLabelBadge` has no call sites; `HistoryPanel` is a stub whose only reference is a commented-out block.

**Work:**
- Delete `TakeNote/Views/Helpers/NoteLabelBadge.swift`
- Delete `TakeNote/Views/HistoryPanel.swift` (or wherever it resides — locate the file first)
- Confirm no remaining source file references `NoteLabelBadge` or `HistoryPanel` by name

**Done when:** Both files are absent, no compilation errors are introduced, and no source file references the deleted type names.

---

## S003: Clean up the commented-out HistoryPanel block in MainWindow.swift

**Intent:** Remove the residual commented-out block referencing `HistoryPanel()` in `MainWindow.swift`. This is dead markup left from a prior partial deletion.

**Work:**
- Open `TakeNote/Views/MainWindow/MainWindow.swift`
- Remove lines 172–175 (the `/* Spacer() HistoryPanel() */` comment block)
- Preserve all surrounding toolbar code; the surrounding `ToolbarItem` group and the `} content: {` opening must remain intact

**Done when:** `MainWindow.swift` contains no reference to `HistoryPanel`, the surrounding toolbar structure is unmodified, and the file compiles.

---

## S004: Remove dead debug methods from SearchIndex.swift

**Intent:** Remove the `debugCount()` and `debugDump(limit:)` methods and their section header comment from `SearchIndex.swift`. These are never called from any production or external code path.

**Work:**
- Open `TakeNote/Library/SearchIndex.swift`
- Remove the `// MARK: Debug Helpers` comment (line 278)
- Remove the `debugCount()` method (lines 280–284)
- Remove the `debugDump(limit:)` method (lines 286–308)
- Ensure the closing `}` of the `SearchIndex` class remains correct

**Done when:** `SearchIndex.swift` contains neither `debugCount` nor `debugDump`, the file ends correctly, and the project compiles.

---

## S005: Remove getLinksToDestinationNote from NoteLinkManager.swift

**Intent:** Remove the `getLinksToDestinationNote(_:)` public wrapper method. Nothing in the codebase calls it; callers use the internal `getLinksForDestinationNote` directly.

**Work:**
- Open `TakeNote/Library/NoteLinkManager.swift`
- Remove the `getLinksToDestinationNote(_:)` method (lines 25–27)
- The `// MARK: Public Methods` comment above it may be removed if no other public methods remain below it in that section, or left if other public methods follow

**Done when:** `NoteLinkManager.swift` does not contain `getLinksToDestinationNote`, and the file compiles without errors.

---

## S006: Remove dead selectedFolder FocusedValues entry from FolderList.swift

**Intent:** Remove the `@Entry var selectedFolder: NoteContainer?` declaration from the `FocusedValues` extension in `FolderList.swift`. This entry is never set or consumed anywhere.

**Work:**
- Open `TakeNote/Views/FolderList/FolderList.swift`
- Remove the `extension FocusedValues { @Entry var selectedFolder: NoteContainer? }` block (lines 11–13)
- If the extension becomes empty after removal, remove the entire extension block

**Done when:** `FolderList.swift` contains no `selectedFolder` declaration and compiles without errors.

---

## S007: Remove dead placement variables from WindowCommands.swift

**Intent:** Remove the two `let placement` local variables in the `body` of `WindowCommands`. Both are assigned but the `CommandGroup` uses `.windowArrangement` directly, making them unreferenced.

**Work:**
- Open `TakeNote/Views/Commands/WindowCommands.swift`
- Remove the `#if os(macOS) let placement = CommandGroupPlacement.windowList #endif` block (lines 36–38)
- Remove the `#if os(iOS) let placement = CommandGroupPlacement.toolbar #endif` block (lines 39–41)
- Confirm `CommandGroup(after: .windowArrangement)` immediately follows with no reference to `placement`

**Done when:** `WindowCommands.swift` contains no `let placement` assignments and compiles without errors or unused-variable warnings.

---

## S008: Update docs to reflect all deletions

**Intent:** Reconcile `.ushabti/docs/` with all code removed in this Phase. Laws L17, L18, and L19 require docs to accurately reflect the codebase before this Phase can be marked complete.

**Work:**
- In `.ushabti/docs/search-system.md`: remove the `VectorSearchIndex` section (describing the in-memory vector index), remove the `EmbeddingProvider` section, and update the Overview paragraph that describes two search indexes — it should describe only the FTS5 index after deletion
- In `.ushabti/docs/supporting-systems.md`: in the `NoteLinkManager` Query Methods subsection, remove the bullet for `getLinksToDestinationNote(_ note: Note) -> [NoteLink]`
- In `.ushabti/docs/views.md`: in the Helper Views section, remove the `NoteLabelBadge` bullet point entry

**Done when:** All three doc files no longer reference deleted code, and the docs accurately describe the current state of the codebase.

---

## S009: Fix stale VectorSearchIndex reference in docs/index.md

**Intent:** The table of contents entry for `search-system.md` in `index.md` still reads "FTS5 SearchIndex, VectorSearchIndex, SearchIndexService, chunking, and RAG usage". `VectorSearchIndex` no longer exists. This stale description violates L18 and L19.

**Work:**
- Open `.ushabti/docs/index.md`
- On line 19, update the description for the `search-system.md` entry to remove the mention of `VectorSearchIndex`
- The corrected line should read: `- [Search System](search-system.md) — FTS5 SearchIndex, SearchIndexService, chunking, and RAG usage`

**Done when:** `index.md` contains no reference to `VectorSearchIndex` and accurately describes `search-system.md`.
