# Search System

## Overview

TakeNote has one search index:

1. **FTS index** (`SearchIndex`) — SQLite FTS5 for full-text search. The sole implementation used in production for both note list search and chat RAG retrieval.

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

- `canReindexAllNotes() -> Bool` — returns `true` only if: not currently indexing, and at least 10 minutes have elapsed since the last full reindex. (The chat feature flag no longer gates this method; indexing is always-on to support note list search.)
- `reindex(note: Note)` — asynchronously reindexes a single note by UUID and content. Always runs regardless of chat feature flag state.
- `reindexAll(_ noteData: [(UUID, String)])` — rate-limited bulk reindex. Only runs if `canReindexAllNotes()` returns `true`. Sets `isIndexing` and resets `lastReindexAllDate`.
- `dropAll()` — clears all indexed data. Always runs regardless of chat feature flag state.
- `deleteFromIndex(noteID: UUID)` — removes all FTS chunks for one note by UUID. Always runs regardless of chat feature flag state. Logs at debug level.
- `searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID]` — returns deduplicated note UUIDs in BM25 rank order by delegating to `index.searchNoteIDs`. Used by `NoteList.filteredNotes` for FTS-backed note list search.

### When Indexing Runs

- **Single note — deselect**: triggered from `NoteList.onChange(of: takeNoteVM.selectedNotes)` when a note is deselected and content has changed. This is the primary single-note reindex path.
- **Single note — note creation (New Note button/toolbar)**: `MainWindow` toolbar Add Note button calls `search.reindex(note:)` immediately after `takeNoteVM.addNote()` returns.
- **Single note — note creation (File menu / keyboard shortcut)**: `FileCommands` New Note command calls `search.reindex(note:)` immediately after `takeNoteVM.addNote()` returns.
- **Single note — note creation (text drop)**: `NoteList` drop-destination for `String.self` calls `search.reindex(note:)` after `addNote()` and `setContent()`.
- **Single note — copy-paste**: `NoteList.pasteNote()` calls `search.reindex(note:)` after `modelContext.insert(newNote)` for the copy-paste branch.
- **Single note — app backgrounding/quit**: `TakeNoteApp.onChange(of: scenePhase)` reindexes `takeNoteVM.openNote` when the scene transitions to `.inactive` or `.background`, capturing mid-edit changes before the process suspends.
- **Single note — detached editor window note change**: `NoteEditorWindow.onChange(of: editorWindowVM.openNote)` reindexes the previous note when the window switches to a different note.
- **Single note — detached editor window close**: `NoteEditorWindow.onDisappear` reindexes the current `editorWindowVM.openNote` when the editor window is closed.
- **Bulk (CloudKit)**: triggered from `AppBootstrapper.installReconciler()` on `NSPersistentStoreRemoteChange` (CloudKit sync), subject to the 10-minute rate limit.
- **Startup**: triggered once per session from `AppBootstrapper.installReconciler()` when `runOnStartup: true` and `canReindexAllNotes()` is satisfied (feature flag on, not currently indexing, 10-minute cooldown elapsed). Runs at app launch before any user interaction with Magic Chat. In DEBUG builds the index is in-memory and starts empty each launch, so the startup reindex runs every DEBUG launch — this is expected and harmless.

### When Index Deletion Runs

All deletion paths run unconditionally via `SearchIndexService.deleteFromIndex(noteID:)`. The chat feature flag no longer gates deletion; the FTS index is always-on.

- **Move to Trash — single note**: `NoteListEntry.moveToTrash()` calls `search.deleteFromIndex(noteID: note.uuid)` immediately after `takeNoteVM.moveNoteToTrash()`. This covers swipe-to-trash, the context menu "Move to Trash" item, and the `noteDeleteRegistry` menu bar command (all routes through `moveToTrash()`).
- **Move to Trash — multi-select**: `NoteListEntry.moveSelectedNotesToTrash()` calls `search.deleteFromIndex(noteID: sn.uuid)` for each note in the selection after its `moveNoteToTrash` call.
- **Empty Trash**: The Empty Trash confirmation alert action in `MainWindow` captures `takeNoteVM.trashFolder?.notes.map { $0.uuid }` before calling `takeNoteVM.emptyTrash(modelContext)`, then calls `search.deleteFromIndex(noteID:)` for each UUID after the deletion completes.

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
- `searchNatural(_ text: String, limit: Int = 5) -> [SearchHit]` — NLP-normalized search. Lemmatizes tokens via `NLTagger`, strips stop words, adds prefix wildcards (`*`) to tokens of 3+ characters, then joins tokens with `" OR "` so any token can match. Results are ordered by BM25 relevance. Example query form: `"note* OR takenot*"`.
- `searchNoteIDs(_ text: String, limit: Int = 500) -> [UUID]` — calls `searchNatural(text, limit: limit)`, deduplicates `SearchHit` results by `noteID` preserving first-occurrence (highest BM25 rank) order, and returns the ordered `[UUID]` list. Purpose-built for note list search in `NoteList.filteredNotes`.
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

## Usage in Note List Search

When `NoteList.filteredNotes` is evaluated with a non-empty `noteSearchText`:

1. `search.searchNoteIDs(noteSearchText)` is called (delegates to `index.searchNoteIDs` with a limit of 500).
2. A `Set<UUID>` is built from the result for O(1) membership tests.
3. The candidate note pool (all non-trash/non-buffer notes for All Notes, or the container's notes for other containers) is filtered to only notes whose `uuid` is in the result set.
4. The filtered notes are sorted by the UUID's index in the FTS result array (BM25 rank order). Note: `sortedNotes` subsequently re-sorts by date/updated order, so FTS rank is used for deduplication but not preserved in the final display order.

When `noteSearchText` is empty, `filteredNotes` returns all candidate notes unchanged (existing behavior).

---

## Usage in Chat RAG

When `ChatWindow.askQuestion()` is called:

1. `search.index.searchNatural(trimmed)` retrieves up to 5 `SearchHit` values.
2. Each `SearchHit.chunk` is injected as a `SOURCE EXCERPT` block in the LLM prompt.
3. The LLM is instructed to answer only from these excerpts.
