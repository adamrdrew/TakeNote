# Steps

## S001: Remove chat feature flag guards from SearchIndexService indexing methods

**Intent:** Decouple the FTS index lifecycle from the chat feature flag so that reindex, delete, and dropAll always run regardless of whether Magic Chat is enabled.

**Work:**
- In `TakeNote/Library/SearchIndexService.swift`, remove the `if chatFeatureFlagEnabled == false { return }` guard from `reindex(note:)`.
- Remove the `if chatFeatureFlagEnabled == false { return }` guard from `reindexAll(_:)`.
- Remove the `if chatFeatureFlagEnabled == false { return }` guard from `deleteFromIndex(noteID:)`.
- Remove the `if chatFeatureFlagEnabled == false { return }` guard from `dropAll()`.
- Remove the `if chatFeatureFlagEnabled == false { return false }` guard from `canReindexAllNotes()`. The remaining guards (`isIndexing` and the 10-minute elapsed check) stay intact.
- The log message in `reindexAll` currently says "RAG search reindex running." — update it to "FTS search reindex running." to reflect the broadened purpose.

**Done when:** None of the five methods (`reindex`, `reindexAll`, `deleteFromIndex`, `dropAll`, `canReindexAllNotes`) contain a `chatFeatureFlagEnabled` check. The app compiles.

---

## S002: Add searchNoteIDs to SearchIndex

**Intent:** Give `SearchIndex` a method purpose-built for note list search that returns deduplicated note UUIDs in BM25 rank order.

**Work:**
- In `TakeNote/Library/SearchIndex.swift`, add a new method:
  ```swift
  func searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID]
  ```
- Implementation: call `searchNatural(text, limit: limit)` to get `[SearchHit]`, then deduplicate by `noteID` preserving first-occurrence order (first occurrence has the highest BM25 rank for that note), and return the resulting `[UUID]`.
- Do not change the FTS5 table schema, `searchNatural`, or `search` methods.

**Done when:** `SearchIndex.searchNoteIDs` exists, compiles, and returns a deduplicated ordered list of UUIDs from `searchNatural` results.

---

## S003: Expose searchNoteIDs through SearchIndexService

**Intent:** Give the view layer a clean call site on the service object rather than reaching into `service.index` directly.

**Work:**
- In `TakeNote/Library/SearchIndexService.swift`, add a new method:
  ```swift
  func searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID] {
      index.searchNoteIDs(text, limit: limit)
  }
  ```

**Done when:** `SearchIndexService.searchNoteIDs` exists, compiles, and delegates to `index.searchNoteIDs`.

---

## S004: Replace NoteList.filteredNotes string filtering with FTS

**Intent:** Route all non-empty search queries through the FTS index instead of `localizedStandardContains`.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, rewrite `filteredNotes` as follows:
  - When `noteSearchText` is empty: keep existing behavior (return all container notes, apply All Notes exclusions as today).
  - When `noteSearchText` is non-empty:
    1. Call `search.searchNoteIDs(noteSearchText)` to get `[UUID]` in FTS rank order.
    2. Build a `Set<UUID>` from the result for O(1) membership tests.
    3. Determine the candidate pool: for All Notes, use `notes.filter { $0.folder?.isTrash != true && $0.folder?.isBuffer != true }`; for other containers, use `takeNoteVM.selectedContainer?.notes ?? []`.
    4. Filter the candidate pool to only notes whose `uuid` is in the result set.
    5. Sort the filtered pool by the UUID's index in the FTS result array (preserving BM25 rank order at this stage, before `sortedNotes` re-sorts by date).
  - Remove the `localizedStandardContains` calls entirely.
- `@Environment(SearchIndexService.self) private var search` is already present on line 126 — no injection change needed.

**Done when:** `filteredNotes` contains no `localizedStandardContains` calls. When search text is non-empty, notes are filtered by FTS UUID results. When search text is empty, behavior is identical to before. The app compiles.

---

## S005: Update documentation

**Intent:** Keep `.ushabti/docs/` accurate after the indexing policy and note list search behavior changes (required by L17/L19).

**Work:**
- In `.ushabti/docs/search-system.md`:
  - Update the `canReindexAllNotes()` description to remove the chat-flag precondition.
  - Update the `reindex(note:)` description: remove "No-op if chat is disabled."
  - Update the `reindexAll(_:)` description: remove the chat-disabled no-op note.
  - Update the `deleteFromIndex(noteID:)` description: remove "No-op if chat is disabled."
  - Update `dropAll()` description: remove the chat-disabled no-op note.
  - Update the "When Index Deletion Runs" note that says all deletion paths are gated on `chatFeatureFlagEnabled` — this is no longer true.
  - Add documentation for `SearchIndex.searchNoteIDs` under Key Methods.
  - Add documentation for `SearchIndexService.searchNoteIDs` under Methods.
- In `.ushabti/docs/views.md`:
  - Update the NoteList section: replace "Filters notes by search text against title and content" with a description of FTS-backed search via `SearchIndexService.searchNoteIDs`.

**Done when:** Both documentation files accurately describe the post-phase behavior. No references to "No-op if chat is disabled" remain for indexing methods. `searchNoteIDs` is documented in both files.

---

## S006: Fix inaccurate join-operator description in search-system.md

**Intent:** Correct a factual error in `.ushabti/docs/search-system.md` introduced during S005: the doc incorrectly states the code uses `" AND "` as the FTS query join separator, but the actual code uses `" OR "`.

**Work:**
- In `.ushabti/docs/search-system.md`, find the `searchNatural` entry under Key Methods. It currently reads (approximately): "**Note:** A source comment says 'join with OR so any token can match' but the actual code uses `' AND '` as the separator. The code is correct (AND gives more relevant results with BM25 ranking); the comment is stale/misleading."
- Replace this note with accurate text. The actual code at `SearchIndex.swift` line 219 is:
  ```swift
  let safeQuery = starred.joined(separator: " OR ")
  ```
  Both the comment and the code use `OR`. There is no discrepancy. Remove the false claim that the code uses AND. If the note about the comment being stale is inaccurate it should be removed entirely; if the comment now accurately describes the code, simply omit the misleading "Note" entirely or replace it with an accurate description of what the query looks like (OR-joined tokens with prefix wildcards).

**Done when:** The `searchNatural` description in `search-system.md` accurately reflects the `" OR "` join in the actual code. No false claim about an AND/OR discrepancy exists.

---

## S007: Bump CURRENT_PROJECT_VERSION and MARKETING_VERSION in project.pbxproj

**Intent:** Satisfy L20, which requires Overseer to increment both version fields in all four occurrences before any Phase is declared complete.

**Work:**
- In `TakeNote.xcodeproj/project.pbxproj`, change all four occurrences of `CURRENT_PROJECT_VERSION = 13` to `CURRENT_PROJECT_VERSION = 14`.
- Change all four occurrences of `MARKETING_VERSION = 1.1.9` to `MARKETING_VERSION = 1.1.10`.

**Done when:** All four `CURRENT_PROJECT_VERSION` entries read `14` and all four `MARKETING_VERSION` entries read `1.1.10` in `project.pbxproj`.
