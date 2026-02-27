# Search System

## Overview

TakeNote has one search index:

1. **FTS index** (`SearchIndex`) — SQLite FTS5 for full-text search. The sole implementation used in production for chat RAG retrieval.

It is managed through `SearchIndexService`, which is the `@Observable` service consumed by the UI.

---

## SearchIndexService

**File:** `TakeNote/Library/SearchIndexService.swift`

`@MainActor`, `@Observable`.

The service layer that wraps `SearchIndex`. Injected into the SwiftUI environment on all windows.

### Properties

| Property | Type | Description |
|---|---|---|
| `index` | `SearchIndex` | The FTS5 index. In-memory in DEBUG; on-disk in release. |
| `hits` | `[SearchHit]` | Last search results (observable). |
| `isIndexing` | `Bool` | `true` while a bulk reindex is running. |
| `lastReindexAllDate` | `Date` | Timestamp of the last full reindex. |

### Methods

- `canReindexAllNotes() -> Bool` — returns `true` only if: chat feature flag is enabled, not currently indexing, and at least 10 minutes have elapsed since the last full reindex.
- `reindex(note: Note)` — asynchronously reindexes a single note by UUID and content. No-op if chat is disabled.
- `reindexAll(_ noteData: [(UUID, String)])` — rate-limited bulk reindex. Only runs if `canReindexAllNotes()` returns `true`. Sets `isIndexing` and resets `lastReindexAllDate`.
- `dropAll()` — clears all indexed data.

### When Indexing Runs

- **Single note**: triggered from `NoteList.onChange(of: takeNoteVM.selectedNotes)` when a note is deselected and content has changed.
- **Bulk**: triggered from `AppBootstrapper.installReconciler()` on `NSPersistentStoreRemoteChange` (CloudKit sync), subject to the 10-minute rate limit.

---

## SearchIndex (FTS5)

**File:** `TakeNote/Library/SearchIndex.swift`

SQLite FTS5 full-text index. Uses the `SQLite.swift` SPM package.

### Storage

- **Debug:** in-memory SQLite connection (intentional — prevents stale on-disk search data in development).
- **Release:** on-disk at the `applicationSupportDirectory` path. On macOS this resolves to `~/Library/Application Support/TakeNote/search.sqlite`. On iOS the path is the app's sandboxed Application Support directory.

### Schema

Single FTS5 virtual table `fts` with columns:
- `note_id` (UNINDEXED) — UUID string of the note.
- `chunk` — indexed text chunk.

### SearchHit

```swift
struct SearchHit: Identifiable {
    public let id: Int64    // FTS rowid
    public let noteID: UUID
    public let chunk: String
}
```

### Key Methods

- `reindex(noteID: UUID, markdown: String)` — deletes all existing chunks for this note, then inserts new chunks from `WindowChunker`. Wrapped in a transaction.
- `reindex(_ notes: [(UUID, String)])` — bulk version, single transaction.
- `delete(noteID: UUID)` — removes all chunks for one note.
- `dropAll()` — clears all rows; runs FTS5 `optimize`, WAL checkpoint, and `VACUUM`. Has a fallback path: if the initial clear fails (e.g., table doesn't exist or is corrupted), it drops and recreates the entire FTS table, then checkpoints and vacuums.
- `search(_ query: String, limit: Int = 5) -> [SearchHit]` — raw FTS5 MATCH query ordered by BM25 relevance.
- `searchNatural(_ text: String, limit: Int = 5) -> [SearchHit]` — NLP-normalized search. Lemmatizes tokens via `NLTagger`, strips stop words, adds prefix wildcards (`*`) to tokens of 3+ characters, joins with `AND`. **Note:** A source comment on line 216 of `SearchIndex.swift` says "join with OR so any token can match" but the actual code on line 218 uses `" AND "` as the separator. The code is correct (AND gives more relevant results with BM25 ranking); the comment is stale/misleading.
- `normalizeQuery(_ text: String, locale: Locale) -> [String]` — returns lemmatized, stop-word-filtered tokens.

### Chunking

**File:** `TakeNote/Library/Chunking.swift`

`WindowChunker` splits a note's Markdown text into `NoteChunk` values of at most `maxChars` characters (default: 1000), splitting at whitespace boundaries. Short notes become a single chunk.

```swift
struct WindowChunker {
    let maxChars: Int
    func chunks(for markdown: String) -> [NoteChunk]
}
struct NoteChunk {
    let text: String
}
```

---

## Usage in Chat RAG

When `ChatWindow.askQuestion()` is called:

1. `search.index.searchNatural(trimmed)` retrieves up to 5 `SearchHit` values.
2. Each `SearchHit.chunk` is injected as a `SOURCE EXCERPT` block in the LLM prompt.
3. The LLM is instructed to answer only from these excerpts.
