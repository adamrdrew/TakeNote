# Phase 0011: Unified FTS Search for Note List

## Intent

Replace `NoteList.filteredNotes` in-memory substring filtering with FTS5-backed search via `SearchIndex` and `SearchIndexService`. Currently the note list filters by `localizedStandardContains()` against title and content; Magic Chat already uses `SearchIndex.searchNatural()` with BM25 ranking, lemmatization, and stop word removal. This Phase unifies both paths behind the FTS index so all note search benefits from ranked, NLP-normalized results.

A prerequisite is decoupling the FTS index lifecycle (reindex, delete, dropAll) from the chat feature flag. The flag previously guarded indexing on the assumption that only Magic Chat needed the index. Now that note list search requires it too, indexing must be always-on. The chat *UI* remains feature-flagged; only indexing is decoupled.

## Scope

**In scope:**
- Remove `chatFeatureFlagEnabled` guards from `SearchIndexService.reindex(note:)`, `reindexAll(_:)`, `deleteFromIndex(noteID:)`, and `dropAll()`.
- Update `canReindexAllNotes()` to remove its chat-flag guard (rate-limit and isIndexing guards remain).
- Add `searchNoteIDs(_ text: String, limit: Int) -> [UUID]` to `SearchIndex` — calls `searchNatural`, deduplicates by noteID preserving BM25 rank order (first occurrence wins), returns ordered unique UUIDs.
- Add a thin `searchNoteIDs(_ text: String, limit: Int) -> [UUID]` wrapper to `SearchIndexService`.
- Replace `NoteList.filteredNotes` string filtering with FTS: when `noteSearchText` is non-empty, call `search.searchNoteIDs()`, then filter/order the container's notes by matching UUID and FTS rank order. When `noteSearchText` is empty, keep existing behavior.
- Confirm `NoteList` already has `@Environment(SearchIndexService.self) private var search` (it does — line 126); no structural injection change needed.
- Update `.ushabti/docs/search-system.md` and `.ushabti/docs/views.md` to reflect the new indexing policy and NoteList search behavior.

**Out of scope:**
- Changes to `SearchIndex` schema or the FTS5 table definition.
- Changes to reindex trigger points (established in phase 0007).
- Changes to how `ChatWindow` retrieves chunks — it continues calling `search.index.searchNatural()` directly.
- Adding a `SearchIndexService` reference to `TakeNoteVM` (violates L09).
- Changing the chat UI feature flag behavior.

## Constraints

- **L07**: Chat UI and Chat toolbar button remain gated on `chatFeatureFlagEnabled`. Only indexing is decoupled. The `canReindexAllNotes()` chat-flag check is the one being removed because note list search requires always-on indexing; this is a deliberate policy change, not a violation.
- **L09**: `TakeNoteVM` must not gain a reference to `SearchIndexService`.
- **L13**: `SearchIndexService.index` must remain of type `SearchIndex` (FTS5). Do not wire `VectorSearchIndex`.
- **L15**: `NoteList` already complies with CommandRegistry register/unregister pairing; no changes to that pattern.
- **L16/L17**: Docs must be updated to reflect the new indexing policy and note list search behavior.
- Style: new service methods use `os.Logger`, not `print()`. Sub-view computed properties on list entry types remain `UpperCamelCase`.

## Acceptance criteria

1. `SearchIndexService.reindex(note:)` does not return early when `chatFeatureFlagEnabled == false`.
2. `SearchIndexService.reindexAll(_:)` does not return early when `chatFeatureFlagEnabled == false`.
3. `SearchIndexService.deleteFromIndex(noteID:)` does not return early when `chatFeatureFlagEnabled == false`.
4. `SearchIndexService.dropAll()` does not return early when `chatFeatureFlagEnabled == false`.
5. `SearchIndexService.canReindexAllNotes()` no longer guards on the chat feature flag (rate-limit and isIndexing guards remain).
6. `SearchIndex` has a method `searchNoteIDs(_ text: String, limit: Int) -> [UUID]` that returns deduplicated UUIDs in BM25 rank order.
7. `SearchIndexService` has a method `searchNoteIDs(_ text: String, limit: Int) -> [UUID]` that delegates to `index.searchNoteIDs`.
8. When `noteSearchText` is non-empty, `NoteList.filteredNotes` uses `search.searchNoteIDs()` to obtain matching UUIDs and returns notes filtered to those UUIDs in FTS rank order.
9. When `noteSearchText` is empty, `NoteList.filteredNotes` returns all container notes unchanged (existing behavior preserved).
10. `ChatWindow` still calls `search.index.searchNatural()` directly and its behavior is unchanged.
11. `.ushabti/docs/search-system.md` accurately describes the new always-on indexing policy and the new `searchNoteIDs` method.
12. `.ushabti/docs/views.md` accurately describes `NoteList.filteredNotes` FTS-backed search behavior.

## Risks / notes

- **L07 policy note**: Removing the chat-flag guard from indexing is a deliberate and necessary change to support always-on note list search. The chat *UI* and toolbar button remain gated. L07's original rationale ("indexing when chat is disabled wastes resources") no longer applies because note list search creates an independent, always-needed use of the index. Builder should note this in progress.yaml.
- **Search limit for note list**: The FTS limit passed to `searchNoteIDs` must be large enough to match all plausible result sets. A limit of 500 is a reasonable upper bound for note list use; chat RAG can continue using its own smaller limit. Builder should pick an appropriate constant.
- **FTS index warm-up**: In DEBUG builds the index is in-memory and empty at launch. Typing in the search bar before the startup reindex completes will return empty results. This is the same behavior as today and is acceptable.
- **`sortedNotes` interaction**: When search is active, `filteredNotes` returns notes ordered by FTS rank. The `sortedNotes` computed property then re-sorts these by date/updated order. This means FTS rank is lost after sorting. This is acceptable for a first pass — the note list will show FTS-matched notes but in date order, not relevance order. A future phase could add a "relevance" sort option; that is out of scope here.
