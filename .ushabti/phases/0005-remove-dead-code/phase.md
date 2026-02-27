# Phase 0005: Remove Dead Code

## Intent

Remove all dead code identified by the Vizier audit. The codebase contains four entire files that are never instantiated or called, six dead methods and properties scattered across five files, and one commented-out reference left behind from a prior deletion. Removing this code reduces build surface, eliminates confusion for future agents consulting the codebase, and brings the code into alignment with L13 (which already forbids wiring `VectorSearchIndex` into production, making its continued presence misleading).

## Scope

**In scope:**
- Delete `VectorSearchIndex.swift` (entire file — `VectorSearchIndex` class and `ChunkRecord` nested struct, never instantiated)
- Delete `EmbeddingProvider.swift` (entire file — only referenced by the deleted `VectorSearchIndex`)
- Delete `NoteLabelBadge.swift` (entire file — SwiftUI view with zero call sites)
- Delete `HistoryPanel.swift` (entire file — stub view whose only reference is a commented-out block)
- Remove `debugCount()` method from `SearchIndex.swift` (lines 281–284, never called externally)
- Remove `debugDump(limit:)` method from `SearchIndex.swift` (lines 287–308, never called from any code path)
- Remove `getLinksToDestinationNote(_:)` wrapper method from `NoteLinkManager.swift` (line 25–27, nothing calls it)
- Remove `selectedFolder` `@Entry` declaration from `FolderList.swift` (line 12, never set or read via `@FocusedValue`)
- Remove two dead `placement` local let variables from `WindowCommands.swift` (lines 37 and 40, assigned but never referenced)
- Clean up the commented-out `HistoryPanel()` block in `MainWindow.swift` (lines 172–175)
- Update `.ushabti/docs/` to remove or correct references to all deleted code

**Out of scope:**
- `Chunking.swift` — `WindowChunker` and `NoteChunk` are live; do not touch
- Any search, chat, or view logic beyond the exact dead symbols identified
- Refactoring or behavioral changes of any kind

## Constraints

- **L13:** `VectorSearchIndex` must not be wired into production — deleting it is consistent with this law; confirm `SearchIndexService.index` remains typed as `SearchIndex` after deletion.
- **L17/L18/L19:** Docs must be updated to reflect all deletions before this Phase can be marked complete. Affected docs: `search-system.md` (VectorSearchIndex and EmbeddingProvider sections), `supporting-systems.md` (getLinksToDestinationNote entry), `views.md` (NoteLabelBadge entry in Helper Views).
- **Style:** No new code is introduced. Removal only.

## Acceptance criteria

1. `VectorSearchIndex.swift` does not exist in the repository.
2. `EmbeddingProvider.swift` does not exist in the repository.
3. `NoteLabelBadge.swift` does not exist in the repository.
4. `HistoryPanel.swift` does not exist in the repository.
5. `SearchIndex.swift` contains neither `debugCount` nor `debugDump`.
6. `NoteLinkManager.swift` does not contain `getLinksToDestinationNote`.
7. `FolderList.swift` does not contain the `selectedFolder` `@Entry` declaration.
8. `WindowCommands.swift` contains no `let placement` assignments.
9. `MainWindow.swift` contains no commented-out `HistoryPanel` block.
10. The project builds without errors or warnings introduced by these removals.
11. `SearchIndexService.index` is still typed as `SearchIndex` (not `VectorSearchIndex`).
12. `.ushabti/docs/search-system.md` no longer documents `VectorSearchIndex` or `EmbeddingProvider` as present code.
13. `.ushabti/docs/supporting-systems.md` no longer documents `getLinksToDestinationNote` as a public method.
14. `.ushabti/docs/views.md` no longer lists `NoteLabelBadge` as a live helper view.

## Risks / notes

- The `MARK: Debug Helpers` comment block in `SearchIndex.swift` (line 278) should be removed along with the two debug methods it headings, as it will be left dangling otherwise.
- `NoteLabelBadge` is listed as a live component in `views.md`. The doc entry must be removed, not merely updated.
- The `HistoryPanel` cleanup in `MainWindow.swift` is a comment removal; the surrounding toolbar code must not be disturbed.
- After deleting the two `placement` variables in `WindowCommands.swift`, verify the `CommandGroup(after: .windowArrangement)` call still compiles correctly (it references `.windowArrangement` directly, not `placement`, so it is unaffected).
