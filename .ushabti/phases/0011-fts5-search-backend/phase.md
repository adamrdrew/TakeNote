# Phase 0011: Switch Search to FTS5 Backend

## Intent

Replace the in-memory `localizedStandardContains` filter in `NoteList` with the existing SQLite FTS5 search index (`SearchIndexService`). The FTS5 index is already used for Magic Chat RAG retrieval; this phase extends its role to serve the user-facing search bar as well, providing BM25-ranked, NLP-normalized results. The index gating on `chatFeatureFlagEnabled` is broadened so that indexing runs unconditionally, decoupling the index's availability from the chat feature flag. This is an intentional deviation from L07's original intent (noted explicitly below).

## Scope

**In scope:**
- Remove `chatFeatureFlagEnabled` guards from `SearchIndexService.reindex(note:)`, `reindexAll(_:)`, `deleteFromIndex(noteID:)`, `dropAll()`, and `canReindexAllNotes()` so the index is always maintained.
- Add `searchQuery: String`, computed `searchIsActive: Bool`, `activateSearch(query:)`, and `clearSearch()` to `TakeNoteVM`.
- Replace `NoteList`'s local `noteSearchText: String` state with a binding to `takeNoteVM.searchQuery`.
- Add debounce logic (300 ms, cancel-on-new-keystroke) to the `.onChange` path; wire `.onSubmit` to call `activateSearch(query:)` immediately.
- Replace `filteredNotes` in-memory filter with an FTS5 `searchNatural` call (limit: 50) when `searchIsActive`, deduplicating by `noteID` and mapping to `Note` objects.
- Short-circuit `sortedNotes` to return `filteredNotes` directly (preserving BM25 relevance order) when `searchIsActive`.
- Update `.ushabti/docs/search-system.md` and `.ushabti/docs/views.md`.

**Out of scope:**
- Changes to `SearchIndex.swift` or `Chunking.swift`.
- Any schema changes to the FTS table.
- UI changes to the search bar chrome.
- Changes to Magic Chat's use of the index.

## Constraints

- **L07** — This phase intentionally broadens L07's indexing gate. L07 currently requires that indexing be gated on `chatFeatureFlagEnabled`. Removing that gate is acknowledged as a deliberate product decision: the FTS5 index now serves a dual purpose (chat RAG and keyword search), so it must be maintained regardless of the chat flag. The chat UI and Chat toolbar button remain gated on `chatFeatureFlagEnabled`. Only the indexing gate is removed. Builder must acknowledge this explicitly in progress notes for S001.
- **L09** — All new state (`searchQuery`, `searchIsActive`, `activateSearch`, `clearSearch`) belongs in `TakeNoteVM`. No new `@Observable` class may be introduced.
- **L13** — `SearchIndexService.index` remains of type `SearchIndex` (FTS5). `VectorSearchIndex` must not be used.
- **Style** — `searchIsActive` follows the `xIsActive` boolean naming convention. `activateSearch(query:)` and `clearSearch()` follow the action method naming conventions. Debounce task uses `@State var debounceTask: Task<Void, Never>?` in `NoteList`.

## Acceptance criteria

1. With chat feature flag disabled, notes are indexed on creation, edit deselection, and deletion — verified by confirming the `reindex`/`deleteFromIndex` no-ops are gone from `SearchIndexService`.
2. Typing in the search bar produces FTS5 results after the debounce delay; submitting produces immediate results.
3. Search results are ordered by BM25 relevance (sort controls have no effect while search is active).
4. Notes in Trash and Buffer do not appear in search results.
5. FTS returns chunks (multiple per note); results deduplicate to unique notes.
6. `searchNatural` is called with `limit: 50` (not the default 5).
7. Clearing the search bar returns to the unfiltered note list for the current container.
8. `activateSearch(query:)` navigates to All Notes if `allNotesFolder` is non-nil; does nothing if nil (nil guard).
9. `sortedNotes` returns `filteredNotes` unsorted when `searchIsActive`.
10. `search-system.md` and `views.md` accurately reflect the new behavior.

## Risks / notes

- **L07 gate broadening**: Acknowledged. Indexing now runs unconditionally. Chat UI surfaces remain gated. This is the highest-risk change in terms of policy compliance and must be called out in S001 progress notes.
- **FTS returns chunks, not notes**: `searchNatural` returns `[SearchHit]` where each `SearchHit` has a `noteID`. Multiple hits may share the same `noteID`. Deduplication must preserve the first (highest BM25) hit per note.
- **`searchNatural` default limit is 5**: The call in `filteredNotes` must explicitly pass `limit: 50`.
- **`allNotesFolder` nil guard**: `activateSearch(query:)` must guard against `allNotesFolder` being nil before assigning it to `selectedContainer`.
- **BM25 relevance order**: `sortedNotes` must short-circuit and return `filteredNotes` unchanged when `searchIsActive`. Applying date-based sort would destroy relevance ranking.
- **Three `TakeNoteVM` instances**: The docs note that three independent `TakeNoteVM` instances can exist (main window, editor window, chat window). `searchQuery` lives on all three; search state in the editor window and chat window VMs is irrelevant — only the main window's VM drives `NoteList`. No cross-instance coordination is needed.
- **Empty index for chat-disabled users**: Solved by S001 removing the flag gate. The startup reindex mechanism already handles populating empty indexes on first launch — no migration code needed.
