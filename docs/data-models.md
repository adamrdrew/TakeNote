# Data Models

TakeNote uses SwiftData with CloudKit sync. All models are in `TakeNote/Models/`.

## Schema Change Warning

When modifying any `@Model` class, you must bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` to trigger CloudKit schema updates in DEBUG builds. Don't forget to promote schema changes to production.

## Note

**File:** `Note.swift`

The primary data model representing a user's note.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `uuid` | `UUID` | Unique identifier (private setter) |
| `title` | `String` | Note title (defaults to "New Note") |
| `content` | `String` | Markdown content |
| `createdDate` | `Date` | Creation timestamp |
| `updatedDate` | `Date` | Last modification timestamp |
| `starred` | `Bool` | Favorited status |
| `aiSummary` | `String` | AI-generated summary |
| `contentHash` | `String` | MD5 hash for change detection |
| `aiSummaryIsGenerating` | `Bool` | Transient flag (not persisted) |

### Relationships

- `folder: NoteContainer?` - Parent folder (inverse: `folderNotes`)
- `tag: NoteContainer?` - Optional tag (inverse: `tagNotes`)
- `starredFolder: NoteContainer?` - Starred container reference (inverse: `starredNotes`)
- `outgoingLinks: [NoteLink]?` - Links from this note to others
- `incomingLinks: [NoteLink]?` - Links from other notes to this one

### Key Methods

**`setTitle(_ newTitle: String)`** - Updates title and `updatedDate`, reloads widgets.

**`setContent(_ newContent: String)`** - Updates content and `updatedDate`, reloads widgets.

**`generateSummary() async`** - Generates AI summary using Apple Foundation Models. Only runs if:
- Content is not empty
- Content has changed (hash comparison)
- Not already generating
- AI is available

**`setTitle()`** (no parameter) - Auto-extracts title from first line of content if title is still default. Strips markdown formatting.

**`contentHasChanged() -> Bool`** - Compares current content MD5 hash against stored `contentHash`.

**`getURL() -> String`** - Returns `takenote://note/{uuid}` deep link.

**`getMarkdownLink() -> String`** - Returns `[title](takenote://note/{uuid})` markdown link.

### NoteIDWrapper

A `Transferable` wrapper for `PersistentIdentifier` used in drag-and-drop and copy/paste operations.

**Quirk:** Eagerly encodes the identifier to `Data` on initialization to avoid SwiftData work during app termination.

```swift
struct NoteIDWrapper: Hashable, Codable, Transferable {
    let id: PersistentIdentifier
    private let snapshot: Data  // eager bytes to avoid work-at-quit
}
```

## NoteContainer

**File:** `NoteContainer.swift`

Represents folders, tags, and system containers. A single model handles all container types via boolean flags.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Display name |
| `symbol` | `String` | SF Symbol name |
| `canBeDeleted` | `Bool` | Whether user can delete |
| `isTrash` | `Bool` | Is the Trash folder |
| `isInbox` | `Bool` | Is the Inbox folder |
| `isStarred` | `Bool` | Is the Starred folder |
| `isBuffer` | `Bool` | Is the cut/paste buffer (hidden) |
| `isTag` | `Bool` | Is a tag (vs folder) |
| `colorRGBA` | `UInt32` | Color as packed RGBA |

### Relationships

- `folderNotes: [Note]?` - Notes in this folder
- `tagNotes: [Note]?` - Notes with this tag
- `starredNotes: [Note]?` - Starred notes (only on Starred container)

### Computed Properties

**`notes: [Note]`** - Smart accessor that returns the appropriate note list:
- Returns `starredNotes` if `isStarred`
- Returns `tagNotes` if `isTag`
- Returns `folderNotes` otherwise

**`color: Color`** - Platform-specific color conversion from `colorRGBA`. Handles macOS, iOS, and visionOS differences in color space.

### System Containers

Four system containers are auto-created on first launch:

| Container | Purpose | Symbol |
|-----------|---------|--------|
| Inbox | Default folder for new notes | `tray` |
| Trash | Deleted notes | `trash` |
| Starred | Favorited notes | `star.fill` |
| Buffer | Hidden cut/paste buffer | `shippingbox` |

System containers cannot be deleted and have their color enforced to `0xFF26B9FF` during reconciliation.

## NoteLink

**File:** `NoteLink.swift`

Represents a bidirectional link between two notes for backlinks functionality.

### Properties

- `source: Note?` - The note containing the link
- `destination: Note?` - The note being linked to

### Relationship Quirk

Inverses are specified on NoteLink (not on Note) to avoid Swift macro circularity issues:

```swift
@Relationship(inverse: \Note.outgoingLinks) var source: Note?
@Relationship(inverse: \Note.incomingLinks) var destination: Note?
```
