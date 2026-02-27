# Review: Phase 0011 — Switch Search to FTS5 Backend

## Summary

Phase 0011 replaces the in-memory `localizedStandardContains` search filter in `NoteList` with the existing SQLite FTS5 index, extends that index to serve user-facing search, and intentionally removes the `chatFeatureFlagEnabled` gate from all indexing paths. All six steps are implemented correctly. All ten acceptance criteria are satisfied. All applicable laws are upheld. Documentation is reconciled. Build version incremented per L20.

## Verified

### S001 — Remove chatFeatureFlagEnabled gate from SearchIndexService

All five methods (`canReindexAllNotes`, `reindex(note:)`, `reindexAll(_:)`, `deleteFromIndex(noteID:)`, `dropAll()`) no longer contain any `chatFeatureFlagEnabled` early return. Each method carries a comment explicitly noting the intentional L07 deviation. Chat UI surfaces (`MainWindow`, `TakeNoteApp`, `WindowCommands`) remain gated on `chatFeatureFlagEnabled`. AC1 satisfied.

### S002 — Add search state and methods to TakeNoteVM

`TakeNoteVM` now has:
- `var searchQuery: String = ""`
- `var searchIsActive: Bool { return !searchQuery.isEmpty }` (computed)
- `func activateSearch(query: String)` — guards `allNotesFolder` with `guard let allNotes = allNotesFolder else { return }`, sets `selectedContainer = allNotes`, sets `searchQuery = query`
- `func clearSearch()` — sets `searchQuery = ""`

Per L09: no new `@Observable` class introduced; all search state is in `TakeNoteVM`. AC7, AC8, and AC9 requirements flow from this step.

### S003 — Rewire NoteList search binding and add debounce

`@State var noteSearchText: String = ""` is gone. `.searchable(text: $takeNoteVM.searchQuery)` binds directly to the VM. `@State var debounceTask: Task<Void, Never>? = nil` is declared. The `.onChange(of: takeNoteVM.searchQuery)` handler cancels the current task, calls `clearSearch()` immediately on empty, and otherwise debounces 300 ms before calling `activateSearch(query:)`. `.onSubmit(of: .search)` cancels `debounceTask` and calls `activateSearch` immediately. AC2 satisfied.

### S004 — Replace filteredNotes in-memory filter with FTS5 search

`filteredNotes` has an early return branch when `takeNoteVM.searchIsActive`. In that branch:
- Calls `search.index.searchNatural(takeNoteVM.searchQuery, limit: 50)` — AC6 satisfied.
- Deduplicates by `noteID` using a `Set<UUID>`, preserving BM25 order — AC5 satisfied.
- Builds a `[UUID: Note]` lookup dictionary from the `@Query` result.
- Filters out notes where `folder?.isTrash == true` or `folder?.isBuffer == true` — AC4 satisfied.

The non-search branches are unchanged. AC3 is supported by S005.

### S005 — Short-circuit sortedNotes to preserve BM25 order during search

`sortedNotes` returns `filteredNotes` directly when `takeNoteVM.searchIsActive` is `true`. Date-based sort is skipped. AC3 and AC9 satisfied.

### S006 — Update documentation

Three doc files updated:

**`.ushabti/docs/search-system.md`**: Overview updated to describe dual purpose. All five method descriptions remove the chat flag condition. "When Indexing Runs" and "When Index Deletion Runs" sections note the unconditional gate removal. New "Usage in Keyword Search" section accurately describes the `filteredNotes` flow: `searchNatural(limit: 50)`, deduplication, UUID lookup, trash/buffer filter, and `sortedNotes` short-circuit. The debounce behavior and `activateSearch` navigation to All Notes are documented.

**`.ushabti/docs/views.md`**: NoteList section updated to document the FTS5 search path, debounce, `searchIsActive` state, and BM25 sort short-circuit. AC10 satisfied for this file.

**`.ushabti/docs/view-model.md`**: Search State table added (`searchQuery`, `searchIsActive`). Search Operations methods section added (`activateSearch`, `clearSearch`). AC10 satisfied for this file (note: `view-model.md` is not listed in AC10 by name, but L17/L18/L19 require it, and it is accurate).

### Laws compliance

- **L07**: Intentional deviation acknowledged in phase.md, step S001 notes, and code comments. Only indexing gates removed; chat UI and toolbar remain gated. The deviation is explicitly sanctioned in phase.md's Constraints section.
- **L09**: All search state in `TakeNoteVM`. No new `@Observable` class.
- **L13**: `SearchIndexService.index` remains of type `SearchIndex` (FTS5). `VectorSearchIndex` is not used.
- **L01**: No `#available` checks below macOS 26 / iOS 26. Deployment targets unchanged.
- **L02/L03**: No new `@Model` types. No schema changes. `ckBootstrapVersionCurrent` not relevant to this phase.
- **L10**: No `modelContext.delete(note)` outside `emptyTrash()`.
- **L17/L18/L19**: Three doc files updated and accurate.
- **L20**: `CURRENT_PROJECT_VERSION` incremented from 13 to 14. `MARKETING_VERSION` incremented from 1.1.9 to 1.1.10. All four occurrences of each field updated (Debug and Release for TakeNote and NewNoteControl targets). Verified in `TakeNote.xcodeproj/project.pbxproj`.

### Style compliance

- `searchQuery`, `searchIsActive`, `activateSearch(query:)`, `clearSearch()` follow established naming conventions.
- `debounceTask` follows `lowerCamelCase` property naming.
- No `print()` calls introduced.
- `os.Logger` usage unchanged; no new logging needs introduced by this phase.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. The phase is complete. All acceptance criteria are met, all laws are upheld, documentation is reconciled, and the build version has been bumped to 14 / 1.1.10.
