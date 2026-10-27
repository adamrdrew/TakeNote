# Search System

## Backend and visibility

Core Spotlight is the production search backend on macOS 27, iOS/iPadOS 27, and visionOS 27. `SearchIndexService` is the `@MainActor`, `@Observable` facade shared by the app windows and App Intents. `NoteSpotlightIndex` adapts Spotlight indexing and ranked `CSUserQuery` searches. The former SQLite/FTS and experimental vector implementations are no longer used.

`NoteSearchEntity` associates each searchable item with its App Entity and the note UUID. Items belong to `com.adamdrew.takenote.notes`, have no expiration, and contain the title, plain-text content, folder/tag keywords, dates, star ranking, and `takenote://note/<UUID>` URL. Search results use one `SearchHit` per note.

Trash, Archive, and the cut/paste Buffer are excluded. `SearchIndexService.isIndexable` enforces this on both full and incremental indexing. Attempting to reindex a hidden note removes it instead. Note-list filtering and entity queries also exclude hidden notes.

## Index lifecycle

Startup, CloudKit remote changes, and note-count changes schedule full snapshots. Note creation/import, note deselection, detached-editor changes, and app backgrounding schedule incremental updates. Trash/archive actions schedule removals. Indexing runs regardless of `MagicChatEnabled`.

One debounced worker serializes every Spotlight write. A full rebuild clears the TakeNote domain and indexes its snapshot; subsequent edits and deletions run afterward. New requests coalesce while work is pending. An in-flight Spotlight write is never replaced by another writer, which prevents a stale snapshot from winning over a newer edit or deletion. Empty snapshots still clear stale items.

`waitForPendingIndexing()` waits for queued writes. In-app searches and Magic Chat wait before querying. A search-generation counter discards results from superseded or cancelled searches.

`NoteSpotlightDelegate` handles system rebuild requests and supplies current content by identifier for `SpotlightSearchTool`. Each fetch owns a separate synchronous `ModelContext`; live SwiftData models never cross suspension points. Every system rebuild request is acknowledged after indexing, including an empty result. The delegate is retained by the search service and installed on the default index.

## Magic Chat

`ChatWindow` supplies Apple's `SpotlightSearchTool` with a Core Spotlight source and the app's delegate. It requests up to 12 results, supports text/similarity/date matching, and observes item, scored-item, and grouped-item replies. SDK 27 wraps each result in `SearchableItem`; its `item` property holds the `CSSearchableItem`.

The Intel iOS simulator SDK omits `SpotlightSearchTool`; its integration is excluded for that build target, and model availability guards preserve the ordinary notes UI.

Result UUIDs and domain identifiers are validated before source links are shown. Replies are attached to the corresponding response ID, deduplicated by note UUID, and ignored after cancellation. The observer is cancelled when a turn finishes, the user starts a new chat, or the view disappears.

## Verification

`TakeNoteTests/MigrationTests.swift` exercises hidden-note filtering, delegate content retrieval, edits/deletes arriving during a suspended full rebuild, empty-library clearing, delete/restore ordering, and searches waiting for pending edits. The service accepts a `NoteSearchIndex` implementation so these tests do not write to the system index.
