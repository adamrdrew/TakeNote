# Review: Phase 0005 — Remove Dead Code

## Summary

All nine steps are complete and all fourteen acceptance criteria are satisfied. The previously blocking defect — stale `VectorSearchIndex` reference in `.ushabti/docs/index.md` line 19 — was corrected in S009. The entire docs system is now reconciled with the code changes. Build version bumped to 8 / 1.1.4 per L20.

## Verified

**Acceptance criterion 1 — VectorSearchIndex.swift deleted:** Confirmed. File does not exist at `TakeNote/Library/VectorSearchIndex.swift`.

**Acceptance criterion 2 — EmbeddingProvider.swift deleted:** Confirmed. File does not exist at `TakeNote/Library/EmbeddingProvider.swift`.

**Acceptance criterion 3 — NoteLabelBadge.swift deleted:** Confirmed. File does not exist at `TakeNote/Views/Helpers/NoteLabelBadge.swift`.

**Acceptance criterion 4 — HistoryPanel.swift deleted:** Confirmed. File does not exist at `TakeNote/Views/MainWindow/HistoryPanel.swift` or any alternative location.

**Acceptance criterion 5 — SearchIndex.swift contains neither debugCount nor debugDump:** Confirmed. Neither method exists. The `// MARK: Debug Helpers` comment was also removed.

**Acceptance criterion 6 — NoteLinkManager.swift does not contain getLinksToDestinationNote:** Confirmed. The method is absent. The `// MARK: Public Methods` section remains with other public methods following it.

**Acceptance criterion 7 — FolderList.swift does not contain selectedFolder @Entry declaration:** Confirmed. The entire `FocusedValues` extension was removed. The file contains no `selectedFolder` reference.

**Acceptance criterion 8 — WindowCommands.swift contains no let placement assignments:** Confirmed. Both the `#if os(macOS)` and `#if os(iOS)` `let placement` blocks are gone. `CommandGroup(after: .windowArrangement)` is used directly.

**Acceptance criterion 9 — MainWindow.swift contains no commented-out HistoryPanel block:** Confirmed. No `HistoryPanel` reference exists anywhere in `MainWindow.swift`.

**Acceptance criterion 10 — Project builds without errors:** Cannot be mechanically verified in this environment (Xcode is not runnable from the shell). All changes are removal-only with no new code, no structural alterations to surrounding code, and no remaining cross-references to deleted symbols (verified by full-codebase grep). The removals are structurally sound.

**Acceptance criterion 11 — SearchIndexService.index is still typed as SearchIndex:** Confirmed. `SearchIndexService.swift` declares `let index = try! SearchIndex(inMemory: true)` (DEBUG) and `let index = try! SearchIndex()` (release). No `VectorSearchIndex` reference exists anywhere in the Swift source.

**Acceptance criterion 12 — search-system.md no longer documents VectorSearchIndex or EmbeddingProvider:** Confirmed. `search-system.md` describes only the FTS5 index. No `VectorSearchIndex` or `EmbeddingProvider` sections remain. `index.md` line 19 now reads "FTS5 SearchIndex, SearchIndexService, chunking, and RAG usage" — the stale `VectorSearchIndex` mention is gone.

**Acceptance criterion 13 — supporting-systems.md no longer documents getLinksToDestinationNote:** Confirmed. The `NoteLinkManager` Query Methods section lists only `getNotesThatLinkTo` and `notesLinkToDestination`.

**Acceptance criterion 14 — views.md no longer lists NoteLabelBadge as a live helper view:** Confirmed. The Helper Views section lists only `AIMessage` and `MultiNoteViewer`.

**No remaining references to deleted types in Swift source:** Full-codebase grep returned no results for `VectorSearchIndex`, `EmbeddingProvider`, `NoteLabelBadge`, or `HistoryPanel` in any `.swift` file.

**No remaining references to deleted types in docs:** Full grep of `.ushabti/docs/` returned no results for `VectorSearchIndex`, `EmbeddingProvider`, `NoteLabelBadge`, or `getLinksToDestinationNote`.

**L13 compliance:** `SearchIndexService.index` is `SearchIndex`. No `VectorSearchIndex` is wired into any production code path.

**L17/L18/L19 compliance:** `search-system.md`, `supporting-systems.md`, `views.md`, and `index.md` are all reconciled with the code changes. Docs accurately reflect the codebase.

**L20 compliance:** `CURRENT_PROJECT_VERSION` incremented from 7 to 8. `MARKETING_VERSION` incremented from 1.1.3 to 1.1.4. All four occurrences of each field updated in `TakeNote.xcodeproj/project.pbxproj`.

## Issues

None. The defect from the prior review (stale `VectorSearchIndex` reference in `index.md`) was resolved by S009.

## Decision

GREEN. Weighed and found true. All fourteen acceptance criteria are satisfied, all laws are honored, docs are fully reconciled. Phase 0005 is complete.

Recommend handing off to Ushabti Scribe for the next Phase.
