# Search System

## Overview

TakeNote implements a full-text search system using SQLite FTS5, with natural language processing for query normalization. The search system powers both user search and RAG (Retrieval-Augmented Generation) for the AI chat feature.

## Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SearchIndex` | `/TakeNote/Library/SearchIndex.swift` | FTS5 database wrapper |
| `SearchIndexService` | `/TakeNote/Library/SearchIndexService.swift` | Observable service layer |
| `WindowChunker` | `/TakeNote/Library/Chunking.swift` | Text chunking for indexing |
| `VectorSearchIndex` | `/TakeNote/Library/VectorSearchIndex.swift` | Embedding-based search (experimental) |

## SearchIndex

**File:** `/TakeNote/Library/SearchIndex.swift`

Core FTS5 implementation using SQLite.swift library.

### Schema

```sql
CREATE VIRTUAL TABLE fts USING fts5(
    note_id UNINDEXED,  -- UUID as string
    chunk               -- searchable text
);
```

### Initialization

```swift
init(
    chunker: WindowChunker = .init(),
    inMemory: Bool = false,
    appSupportSubdir: String = "TakeNote"
) throws
```

- **DEBUG:** Uses in-memory database
- **RELEASE:** Persists to `~/Library/Application Support/TakeNote/search.sqlite`

### Indexing Methods

```swift
func reindex(noteID: UUID, markdown: String)
// Deletes existing chunks for note, inserts new chunks

func reindex(_ notes: [(UUID, String)])
// Bulk reindex in single transaction

func delete(noteID: UUID)
// Removes note from index

func dropAll()
// Clears entire index, optimizes, vacuums
```

### Search Methods

```swift
func search(_ query: String, limit: Int = 5) -> [SearchHit]
// Raw FTS5 search with BM25 ranking

func searchNatural(_ text: String, limit: Int = 5) -> [SearchHit]
// Natural language search with query normalization
```

### SearchHit Result Type

```swift
struct SearchHit: Identifiable {
    let id: Int64      // FTS rowid
    let noteID: UUID   // Source note
    let chunk: String  // Matching text chunk
}
```

### Query Normalization

The `normalizeQuery` method processes natural language queries:

1. Normalize apostrophes and diacritics
2. Tokenize using NLTagger
3. Lemmatize words (e.g., "running" -> "run")
4. Remove stopwords
5. Add prefix wildcards to tokens >= 3 chars

```swift
func normalizeQuery(_ text: String, locale: Locale = .init(identifier: "en")) -> [String]
```

**Stopwords:** Common English words (articles, prepositions, pronouns) that are filtered from queries.

### Natural Language Search Flow

```
User Query: "What are my meeting notes?"
    │
    ▼
Normalize: ["meeting", "note"]
    │
    ▼
Add wildcards: ["meeting*", "note*"]
    │
    ▼
Join with AND: "meeting* AND note*"
    │
    ▼
FTS5 MATCH query with BM25 ranking
    │
    ▼
Return top N SearchHit results
```

## SearchIndexService

**File:** `/TakeNote/Library/SearchIndexService.swift`

Observable wrapper providing MainActor-safe access to SearchIndex.

### Properties

```swift
@MainActor
@Observable
class SearchIndexService {
    let index: SearchIndex           // Underlying FTS index
    var hits: [SearchHit] = []       // Current search results
    var isIndexing: Bool = false     // Indexing in progress
    var lastReindexAllDate: Date     // Throttle for bulk reindex
}
```

### Methods

```swift
func canReindexAllNotes() -> Bool
// Checks: feature flag, not indexing, 10+ minutes since last reindex

func reindex(note: Note)
// Index single note (async)

func reindexAll(_ noteData: [(UUID, String)])
// Bulk reindex with throttling

func dropAll()
// Clear index
```

### Reindex Triggers

Bulk reindexing occurs on CloudKit remote changes:

```swift
// In AppBootstrapper.installReconciler
NotificationCenter.default.addObserver(
    forName: .NSPersistentStoreRemoteChange,
    ...
) { _ in
    if searchIndexService.canReindexAllNotes() {
        let notes = try? ctx.fetch(FetchDescriptor<Note>())
        searchIndexService.reindexAll(notes.map { ($0.uuid, $0.content) })
    }
}
```

## WindowChunker

**File:** `/TakeNote/Library/Chunking.swift`

Splits note content into overlapping chunks for indexing.

### Configuration

```swift
struct WindowChunker {
    let maxChunkSize: Int = 1000    // Characters per chunk
    let overlap: Int = 100          // Overlap between chunks
}
```

### Output

```swift
struct Chunk {
    let text: String
    let startIndex: Int
    let endIndex: Int
}

func chunks(for markdown: String) -> [Chunk]
```

Overlapping chunks ensure search terms spanning chunk boundaries are still found.

## VectorSearchIndex (Experimental)

**File:** `/TakeNote/Library/VectorSearchIndex.swift`

Embedding-based semantic search using Apple's embedding APIs.

### Purpose

Provides semantic similarity search as an alternative to keyword-based FTS5. Useful for finding conceptually related content even when exact words don't match.

### Integration

```swift
struct EmbeddingProvider {
    func embed(_ text: String) async throws -> [Float]
}
```

The vector index is present in the codebase but not actively used in the main search flow.

## Environment Integration

SearchIndexService is distributed through SwiftUI environment:

```swift
// In TakeNoteApp
MainWindow()
    .environment(search)
    .focusedSceneValue(search)

// In views
@Environment(SearchIndexService.self) private var search
```

## Debug Helpers

SearchIndex provides debugging methods:

```swift
func debugCount() -> Int           // Row count in FTS table
func debugDump(limit: Int = 5)     // Print sample rows to logger
```
