# Steps

## S001: Remove chatFeatureFlagEnabled gate from SearchIndexService

**Intent:** The FTS5 index now serves both chat RAG and keyword search. It must be maintained regardless of whether the chat feature flag is enabled. This step decouples index maintenance from the chat flag while leaving chat UI surfaces gated as before.

**Work:**
- In `SearchIndexService.reindex(note:)`: remove the `if chatFeatureFlagEnabled == false { return }` guard.
- In `SearchIndexService.reindexAll(_:)`: remove the `if chatFeatureFlagEnabled == false { return }` guard.
- In `SearchIndexService.deleteFromIndex(noteID:)`: remove the `if chatFeatureFlagEnabled == false { return }` guard.
- In `SearchIndexService.dropAll()`: remove the `if chatFeatureFlagEnabled == false { return }` guard.
- In `SearchIndexService.canReindexAllNotes()`: remove the `if chatFeatureFlagEnabled == false { return false }` guard. The remaining checks (`isIndexing`, 10-minute cooldown) are preserved.
- Add a comment above each changed method noting the intentional L07 deviation: the index now serves dual purpose and is unconditionally maintained.

**Done when:** None of the five methods contains a `chatFeatureFlagEnabled` early return. The chat UI and toolbar button are unchanged.

---

## S002: Add search state and methods to TakeNoteVM

**Intent:** Centralize search state in `TakeNoteVM` per L09, giving `NoteList` and any future consumer a single source of truth for the active search query and search mode.

**Work:**
- Add `var searchQuery: String = ""` property to `TakeNoteVM`.
- Add computed property `var searchIsActive: Bool { return !searchQuery.isEmpty }`.
- Add method `func activateSearch(query: String)` that: (1) guards `guard let allNotes = allNotesFolder else { return }`, (2) sets `selectedContainer = allNotes`, (3) sets `searchQuery = query`.
- Add method `func clearSearch()` that sets `searchQuery = ""`. Does not change `selectedContainer` (stays on All Notes after clearing).

**Done when:** `TakeNoteVM` compiles with the four new members. `searchIsActive` returns `true` when `searchQuery` is non-empty and `false` when empty.

---

## S003: Rewire NoteList search binding and add debounce

**Intent:** Connect the `.searchable` modifier to `takeNoteVM.searchQuery` instead of local state, and add debounce so FTS queries fire only after the user pauses typing (or immediately on submit).

**Work:**
- Remove `@State var noteSearchText: String = ""` from `NoteList`.
- In the `body`, replace `$noteSearchText` in `.searchable(text:)` with a `Binding` to `takeNoteVM.searchQuery`: use `@Bindable var takeNoteVM = takeNoteVM` (already present in `body`) and pass `$takeNoteVM.searchQuery`.
- Add `@State var debounceTask: Task<Void, Never>? = nil` to `NoteList`.
- Add `.onChange(of: takeNoteVM.searchQuery)` modifier that:
  1. Cancels the current `debounceTask`.
  2. If the new value is empty, calls `takeNoteVM.clearSearch()` immediately (no debounce needed for clear).
  3. Otherwise, creates a new `Task` assigned to `debounceTask` that: `try? await Task.sleep(for: .milliseconds(300))`, then (if not cancelled) calls `takeNoteVM.activateSearch(query: newValue)`.
- Add `.onSubmit(of: .search)` modifier that: cancels `debounceTask`, calls `takeNoteVM.activateSearch(query: takeNoteVM.searchQuery)` immediately.

**Done when:** Typing in the search bar debounces by 300 ms before activating. Pressing Return activates immediately. Clearing the search bar clears the query immediately.

---

## S004: Replace filteredNotes in-memory filter with FTS5 search

**Intent:** When search is active, use the FTS5 index for ranked results instead of the linear in-memory `localizedStandardContains` scan.

**Work:**
- In `NoteList.filteredNotes`, add an early return branch at the top of the computed property: `if takeNoteVM.searchIsActive`.
- In the search-active branch: call `search.index.searchNatural(takeNoteVM.searchQuery, limit: 50)` to get `[SearchHit]`.
- Deduplicate hits by `noteID` preserving order (first occurrence wins, which is highest BM25): iterate hits in order, tracking seen UUIDs in a `Set<UUID>`; keep only the first hit per `noteID`.
- Build a `[UUID: Note]` lookup dictionary from `notes` (the existing `@Query` result).
- Map deduplicated hit `noteID` values to `Note` objects via the dictionary, using `compactMap`.
- Filter out notes whose `folder?.isTrash == true` or `folder?.isBuffer == true`.
- Return the resulting `[Note]` array.
- The non-search branches below the early return remain unchanged.

**Done when:** When `searchIsActive` is `true`, `filteredNotes` returns FTS5-ranked notes with trash/buffer excluded and no duplicates. When `searchIsActive` is `false`, `filteredNotes` behaves identically to before.

---

## S005: Short-circuit sortedNotes to preserve BM25 order during search

**Intent:** BM25 relevance order from FTS5 must not be overwritten by the date-based sort when search is active.

**Work:**
- In `NoteList.sortedNotes`, add an early return at the top: `if takeNoteVM.searchIsActive { return filteredNotes }`.
- The existing sort logic below runs only when search is not active.

**Done when:** When `takeNoteVM.searchIsActive` is `true`, `sortedNotes` returns `filteredNotes` in BM25 order. When `false`, the sort behaves as before.

---

## S006: Update documentation

**Intent:** Docs must reflect the new dual-purpose index, the removed chat flag gate, and the new search behavior in NoteList and TakeNoteVM (per L17 and L19).

**Work:**
- In `.ushabti/docs/search-system.md`:
  - Update `canReindexAllNotes()` description: remove the chat flag condition. New description: returns `true` only if not currently indexing and at least 10 minutes have elapsed since the last full reindex.
  - Update `reindex(note:)` description: remove "No-op if chat is disabled."
  - Update `reindexAll(_:)` description: remove chat flag condition.
  - Update `dropAll()` description: remove "No-op" caveat.
  - Update `deleteFromIndex(noteID:)` description: remove "No-op if chat is disabled."
  - Update the "When Indexing Runs" section: note that indexing is now unconditional (not gated on chat flag).
  - Update the "When Index Deletion Runs" section: note that deletion is now unconditional.
  - Add a "Usage in Keyword Search" section describing the new search flow: `NoteList.filteredNotes` calls `searchNatural(limit: 50)` when `searchIsActive`, deduplicates by `noteID`, maps to `Note` objects, and filters trash/buffer.
- In `.ushabti/docs/views.md`:
  - Update the `NoteList` section: replace the description of filtering by `localizedStandardContains` with the new FTS5 search behavior. Note the debounce, the `searchIsActive` state, and the BM25 sort short-circuit.
- In `.ushabti/docs/view-model.md`:
  - Add `searchQuery`, `searchIsActive`, `activateSearch(query:)`, and `clearSearch()` to the appropriate State Properties and Methods sections.

**Done when:** All three doc files accurately describe the implemented behavior and contain no references to the removed `chatFeatureFlagEnabled` indexing gate.
