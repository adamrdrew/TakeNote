# Data Models

## Overview

TakeNote uses SwiftData with CloudKit synchronization for persistence. Three model types define the data layer: `Note`, `NoteContainer`, and `NoteLink`.

## Note

The primary content model representing a single markdown note.

**File:** `/TakeNote/Models/Note.swift`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `uuid` | `UUID` | Unique identifier (private setter) |
| `title` | `String` | Note title (defaults to "New Note") |
| `content` | `String` | Markdown content |
| `createdDate` | `Date` | Creation timestamp |
| `updatedDate` | `Date` | Last modification timestamp |
| `starred` | `Bool` | Favorite status |
| `aiSummary` | `String` | AI-generated summary |
| `contentHash` | `String` | MD5 hash for change detection |
| `aiSummaryIsGenerating` | `Bool` | Transient; not persisted |
| `isEmpty` | `Bool` | Computed; true if content is empty |

### Relationships

| Relationship | Type | Inverse | Delete Rule |
|--------------|------|---------|-------------|
| `folder` | `NoteContainer?` | `folderNotes` | noAction |
| `tag` | `NoteContainer?` | `tagNotes` | nullify |
| `starredFolder` | `NoteContainer?` | `starredNotes` | nullify |
| `outgoingLinks` | `[NoteLink]?` | `sourceNote` | - |
| `incomingLinks` | `[NoteLink]?` | `destinationNote` | - |

### Key Methods

```swift
func setTitle(_ newTitle: String)      // Updates title and timestamp
func setContent(_ newContent: String)  // Updates content and timestamp
func setFolder(_ folder: NoteContainer)
func setTag(_ tag: NoteContainer)
func getURL() -> String                // Returns takenote://note/{uuid}
func getMarkdownLink() -> String       // Returns [title](url)
func generateContentHash() -> String   // MD5 hash of content
func contentHasChanged() -> Bool       // Compares current hash to stored
func canGenerateAISummary() -> Bool    // Checks AI availability and state
func generateSummary() async           // Generates AI summary
func setTitle()                        // Auto-sets title from first line
```

### Widget Integration

All setter methods call `WidgetCenter.shared.reloadAllTimelines()` to keep widgets updated.

### NoteIDWrapper

A `Transferable` wrapper for `PersistentIdentifier` used in drag-and-drop and window management:

```swift
struct NoteIDWrapper: Hashable, Codable, Transferable {
    let id: PersistentIdentifier
    private let snapshot: Data  // Pre-encoded for safe export
}
```

Custom UTType: `com.adamdrew.takenote.noteid`

## NoteContainer

Represents folders, tags, and special system containers.

**File:** `/TakeNote/Models/NoteContainer.swift`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Display name |
| `symbol` | `String` | SF Symbol name (default: "folder") |
| `colorRGBA` | `UInt32` | Color as packed RGBA (default: pink) |
| `canBeDeleted` | `Bool` | Internal; false for system containers |
| `isTrash` | `Bool` | Internal; trash folder marker |
| `isInbox` | `Bool` | Internal; inbox folder marker |
| `isStarred` | `Bool` | Internal; starred container marker |
| `isTag` | `Bool` | Internal; tag vs folder |
| `isBuffer` | `Bool` | Internal; clipboard buffer folder |
| `isSystemFolder` | `Bool` | Computed; true if trash, inbox, or starred |

### Relationships

| Relationship | Type | Description |
|--------------|------|-------------|
| `folderNotes` | `[Note]?` | Notes in this folder |
| `tagNotes` | `[Note]?` | Notes tagged with this tag |
| `starredNotes` | `[Note]?` | Starred notes (starred container only) |

### Computed Property: notes

Returns the appropriate note array based on container type:

```swift
var notes: [Note] {
    if isTag { return tagNotes ?? [] }
    if isStarred { return starredNotes ?? [] }
    return folderNotes ?? []
}
```

### Key Methods

```swift
func getSystemImageName() -> String  // Dynamic icon (empty vs filled)
func getColor() -> Color             // Decodes colorRGBA to SwiftUI Color
func setColor(_ color: Color)        // Encodes Color to colorRGBA
```

### System Containers

The app creates four special containers on startup:

| Container | Symbol | Purpose |
|-----------|--------|---------|
| Inbox | `tray` | Default location for new notes |
| Trash | `trash` | Deleted notes before permanent removal |
| Starred | `star.fill` | Virtual folder for favorited notes |
| Buffer | `shippingbox` | Temporary storage for cut notes |

## NoteLink

Represents a directional link between two notes (for backlinks feature).

**File:** `/TakeNote/Models/NoteLink.swift`

### Relationships

| Relationship | Type | Inverse | Description |
|--------------|------|---------|-------------|
| `sourceNote` | `Note?` | `outgoingLinks` | Note containing the link |
| `destinationNote` | `Note?` | `incomingLinks` | Note being linked to |

### Usage

Links are extracted from note content by parsing `takenote://note/{uuid}` URLs in markdown links. The `NoteLinkManager` handles creation and cleanup of link models.

## CloudKit Considerations

All models sync via CloudKit. Important notes:

1. **Schema Changes** - Bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` when modifying models
2. **Duplicate Handling** - `SystemFolderReconciler` merges duplicate system folders from sync conflicts
3. **DEBUG vs RELEASE** - Debug builds use a separate local store; Release uses CloudKit
