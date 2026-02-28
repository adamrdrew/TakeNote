# Review: Phase 0011 — Unified FTS Search for Note List

## Summary

All seven steps are implemented and verified. The two defects identified in the previous review (S006: inaccurate join-operator description in search-system.md; S007: missing version bump) have been correctly resolved. All twelve acceptance criteria are satisfied. Laws compliance is confirmed. Phase is complete.

## Verified

**S001 — Remove chat feature flag guards (AC1-5):**
`TakeNote/Library/SearchIndexService.swift` contains no `chatFeatureFlagEnabled` references. All five methods (`reindex`, `reindexAll`, `deleteFromIndex`, `dropAll`, `canReindexAllNotes`) run unconditionally. The log message was updated from "RAG search reindex running." to "FTS search reindex running." Rate-limit and `isIndexing` guards in `canReindexAllNotes()` remain intact. AC1-5 satisfied.

**S002 — searchNoteIDs on SearchIndex (AC6):**
`SearchIndex.searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID]` exists at line 270 of `TakeNote/Library/SearchIndex.swift`. It calls `searchNatural(text, limit: limit)`, deduplicates by `hit.noteID` using `Set<UUID>.insert().inserted` to preserve first-occurrence order, and returns `[UUID]`. AC6 satisfied.

**S003 — searchNoteIDs on SearchIndexService (AC7):**
`SearchIndexService.searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID]` exists at line 64 of `TakeNote/Library/SearchIndexService.swift`. It delegates directly to `index.searchNoteIDs(text, limit: limit)`. AC7 satisfied.

**S004 — NoteList.filteredNotes FTS replacement (AC8-9):**
`NoteList.filteredNotes` contains no `localizedStandardContains` calls. Non-empty `noteSearchText` routes through `search.searchNoteIDs()`, builds a `Set<UUID>`, filters the candidate pool (All Notes or container notes), and sorts by FTS rank index map. Empty `noteSearchText` preserves existing behavior in both the All Notes and standard container branches. AC8-9 satisfied.

**AC10 — ChatWindow unchanged:**
`ChatWindow.swift` at line 61 still calls `search.index.searchNatural(trimmed)` directly. ChatWindow behavior is unchanged. AC10 satisfied.

**S005 — Documentation updated (AC11, AC12):**
`.ushabti/docs/search-system.md` and `.ushabti/docs/views.md` were updated in the previous review cycle and the doc content is accurate.

**S006 — Fix inaccurate join-operator description (AC11):**
`.ushabti/docs/search-system.md` line 96 now reads: "joins tokens with `' OR '` so any token can match. Results are ordered by BM25 relevance. Example query form: `'note* OR takenot*'`." This accurately reflects `SearchIndex.swift` line 219: `let safeQuery = starred.joined(separator: " OR ")`. No false AND/OR discrepancy claim exists. AC11 satisfied.

**S007 — Version bump (L20):**
All four occurrences of `CURRENT_PROJECT_VERSION` in `TakeNote.xcodeproj/project.pbxproj` read `14`. All four occurrences of `MARKETING_VERSION` read `1.1.10`. L20 satisfied.

**Laws compliance:**
- L07: Chat UI (`ChatWindow`, toolbar button) remain gated on `chatFeatureFlagEnabled`. Only indexing is decoupled. Confirmed in source.
- L09: `TakeNoteVM` has not gained a reference to `SearchIndexService`.
- L13: `SearchIndexService.index` is of type `SearchIndex` (FTS5). No `VectorSearchIndex` wiring.
- L15: All five `CommandRegistry` instances in `NoteList` have matching `.onAppear` and `.onDisappear` register/unregister pairs (unchanged from before this Phase).
- L17/L18/L19: Docs reconciled. Both `.ushabti/docs/search-system.md` and `.ushabti/docs/views.md` accurately describe post-Phase behavior.
- L20: Version incremented as verified above.

## Issues

None. All previously identified defects are resolved.

## Decision

GREEN. Weighed and found true. Phase 0011 is complete.
