# Search System

TakeNote has a dual search system: FTS5 full-text search and in-memory vector embeddings.

## Architecture Overview

```
User Query
    │
    ├──► SearchIndex (FTS5)
    │       └── SQLite with lemmatization
    │
    └──► VectorSearchIndex
            └── Cosine similarity on embeddings
```

## Full-Text Search (FTS5)

**File:** `SearchIndex.swift`

### Database Schema

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts
USING fts5(note_id UNINDEXED, chunk)
```

- `note_id`: Note's PersistentIdentifier (not indexed)
- `chunk`: Searchable text chunks (~1000 chars each)

### Storage Location

`~/Library/Application Support/TakeNote/search.sqlite`

### Chunking

Notes are split into ~1000 character windows at whitespace boundaries using `WindowChunker`:

```swift
let windows = WindowChunker.chunk(text: markdown, windowSize: 1000)
```

### Query Processing

**`searchNatural(text:)`** performs "forgiving" search:

1. **Normalize query:** Handle apostrophes, diacritics, possessives
2. **Tokenize:** Split on non-letter/number boundaries
3. **Filter stopwords:** Comprehensive English stopword list
4. **Lemmatize:** Use `NLTagger` to get word roots
5. **Add wildcards:** Prefix `*` to tokens >= 3 chars
6. **Join with AND:** All terms must match

**Stopwords list includes:**
```swift
"the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
"of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
"be", "have", "has", "had", "do", "does", "did", "will", "would",
"could", "should", "may", "might", "must", "shall", "can", "need",
"dare", "ought", "used", "this", "that", "these", "those", "i", "you",
"he", "she", "it", "we", "they", "what", "which", "who", "whom",
"whose", "where", "when", "why", "how", "all", "each", "every",
"both", "few", "more", "most", "other", "some", "such", "no", "nor",
"not", "only", "own", "same", "so", "than", "too", "very", "just",
"s", "t", "don"
```

### Indexing Operations

**`reindex(noteID:, markdown:)`** - Replace all chunks for a note:
```swift
try db.run(table.filter(noteIdCol == noteID).delete())
for chunk in windows {
    try db.run(table.insert(noteIdCol <- noteID, chunkCol <- chunk))
}
```

**`dropAll()`** - Clear entire index:
```swift
try db.run(table.delete())
try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
try db.execute("VACUUM")
```

### Thread Safety

- Single SQLite connection with `busyTimeout = 5` seconds
- All operations on same connection (no concurrent writes)

## Vector Search

**File:** `VectorSearchIndex.swift`

In-memory vector store for semantic search.

### Embedding Provider

**File:** `EmbeddingProvider.swift`

Uses `NLEmbedding.sentenceEmbedding()` from NaturalLanguage framework.

```swift
guard let embedding = NLEmbedding.sentenceEmbedding(for: .english, revision: 1),
      let raw = embedding.vector(for: text) else { return nil }

// L2 normalize
let norm = sqrt(raw.reduce(0) { $0 + $1 * $1 }) + 1e-12
return raw.map { Float($0 / norm) }
```

### Storage

In-memory arrays (not persisted):
```swift
var rowIDs: [Int64] = []
var noteIDs: [PersistentIdentifier] = []
var vectors: [[Float]] = []
var texts: [String] = []
```

### Search Algorithm

**`search(query:, topK:)`**:

1. Embed query text
2. For each stored vector, compute cosine similarity (dot product of unit vectors)
3. Use fixed-size min-heap for top-k retrieval
4. Return results sorted by score descending

```swift
struct HeapEntry: Comparable {
    let score: Float
    let index: Int
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.score < rhs.score }
}
```

### Row ID Overflow

Uses wrapping arithmetic to handle overflow:
```swift
nextRowID &+= 1
```

## SearchIndexService

**File:** `SearchIndexService.swift`

High-level wrapper coordinating both search backends.

### Feature Flag

All indexing gated by `chatFeatureFlagEnabled`:
```swift
guard chatFeatureFlagEnabled else { return }
```

### Rate Limiting

Full reindex limited to once per 10 minutes:
```swift
func canReindexAllNotes() -> Bool {
    guard let last = lastFullReindex else { return true }
    return Date().timeIntervalSince(last) > 600
}
```

### Methods

**`reindex(note:)`** - Index single note after changes:
```swift
Task.detached {
    self.index.reindex(noteID: note.id, markdown: note.content)
}
```

**`reindexAll()`** - Bulk reindex after CloudKit sync:
```swift
func reindexAll() {
    guard canReindexAllNotes() else { return }
    lastFullReindex = Date()
    // ... fetch all notes and reindex
}
```

## Integration Points

### Note Deselection (NoteList.swift)

When a note is deselected, trigger reindex:
```swift
.onChange(of: selectedNotes) { old, new in
    let deselected = old.subtracting(new)
    for note in deselected {
        search.reindex(note: note)
    }
}
```

### CloudKit Sync (AppBootstrapper.swift)

On remote change notification:
```swift
if searchIndexService.canReindexAllNotes() {
    searchIndexService.reindexAll()
}
```

### Chat RAG (ChatWindow.swift)

Search results included in AI prompts:
```swift
let results = search.index.searchNatural(query: userMessage)
// Results added as "SOURCE EXCERPTS" in prompt
```
