# Data Models

## Overview

All persistent data is stored via SwiftData using four `@Model` classes: `Note`, `NoteContainer`, `NoteLink`, and `NoteImage`. The SwiftData container is CloudKit-backed under `iCloud.com.adamdrew.takenote`.

**Important:** Any change to a model class schema requires bumping `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` and promoting the schema change to the production CloudKit container.

---

## Note

**File:** `TakeNote/Models/Note.swift`

Represents a single note.

### Fields

| Field | Type | Description |
|---|---|---|
| `defaultTitle` | `String` | Persisted field, defaults to `"New Note"`. Used as a sentinel by the no-arg `setTitle()` to detect whether the title is still the auto-derived default. **This is a persisted field** — schema changes to it require a `ckBootstrapVersionCurrent` bump. |
| `title` | `String` | Display title. Property default is `""` (empty string). The `init(folder:)` initializer sets `self.title = self.defaultTitle`, so newly created notes start with `"New Note"`. Auto-derived from first line of content via the no-arg `setTitle()`. |
| `content` | `String` | Raw Markdown text. |
| `createdDate` | `Date` | Creation timestamp. |
| `updatedDate` | `Date` | Last-modified timestamp. Updated by all mutating methods. |
| `starred` | `Bool` | Whether this note appears in the Starred folder. |
| `aiSummary` | `String` | AI-generated one-sentence summary. Stored in the database. |
| `contentHash` | `String` | MD5 hex hash of `content`. Used to avoid regenerating AI summaries when content hasn't changed. |
| `aiSummaryIsGenerating` | `Bool` | `@Transient` (not persisted). In-memory flag while generation is running. |
| `uuid` | `UUID` | Stable identifier used for deep links and the FTS/vector search index. Private setter (`private(set)`); SwiftData can still set it via internal hydration. |

### Relationships

| Relationship | Type | Description |
|---|---|---|
| `folder` | `NoteContainer?` | The folder this note lives in. Delete rule: `.noAction` (notes are moved to Trash, not deleted). |
| `tag` | `NoteContainer?` | Optional tag assigned to this note. Delete rule: `.nullify`. |
| `starredFolder` | `NoteContainer?` | Reference to the Starred container when `starred == true`. Delete rule: `.nullify`. |
| `outgoingLinks` | `[NoteLink]?` | Links where this note is the source. Declared with `@Relationship` but no explicit `deleteRule` (SwiftData default applies). Inverses are specified on `NoteLink` side to avoid macro circularity. |
| `incomingLinks` | `[NoteLink]?` | Links where this note is the destination. Same relationship pattern as `outgoingLinks`. |

### Computed Properties

- `isEmpty: Bool` — returns `content.isEmpty`. Used by `canGenerateAISummary()` to skip summary generation on empty notes.

### Key Methods

- `setTitle(_ newTitle: String)` — sets title and updates `updatedDate`; triggers widget reload.
- `setContent(_ newContent: String)` — sets content and updates `updatedDate`; triggers widget reload.
- `setFolder(_ folder: NoteContainer)` — moves note to a folder; updates `updatedDate`; triggers widget reload.
- `setTag(_ tag: NoteContainer)` — assigns a tag; updates `updatedDate`; triggers widget reload.
- `setTitle()` (no-arg) — derives title from first line of content if `title` still equals `defaultTitle`. Strips Markdown formatting via `AttributedString`. Calls `setTitle(_:)` internally (so it triggers the widget reload and updatedDate update).
- `getURL() -> String` — returns `"takenote://note/<UUID>"` deep link string.
- `getMarkdownLink() -> String` — returns `"[title](takenote://note/<UUID>)"`.
- `generateContentHash() -> String` — MD5 hex of content.
- `contentHasChanged() -> Bool` — compares stored hash with fresh hash.
- `canGenerateAISummary() -> Bool` — checks content non-empty, content changed, not already generating, and AI available.
- `generateSummary() async` — invokes `LanguageModelSession` to produce a one-sentence summary; stores result in `aiSummary`.

### NoteIDWrapper

A `Hashable, Codable, Transferable` wrapper around a `PersistentIdentifier`. Used for drag-and-drop and copy/cut/paste of notes (macOS). Conforms to `TransferRepresentation` via a custom UTType (`com.adamdrew.takenote.noteid`).

---

## NoteContainer

**File:** `TakeNote/Models/NoteContainer.swift`

A single model class that serves multiple conceptual roles: folder, tag, and system containers. Discriminated by boolean flags.

### Fields

| Field | Type | Description |
|---|---|---|
| `name` | `String` | Display name. |
| `folderNotes` | `[Note]?` | Notes whose `folder` is this container. |
| `tagNotes` | `[Note]?` | Notes whose `tag` is this container. |
| `starredNotes` | `[Note]?` | Notes whose `starredFolder` is this container. |
| `canBeDeleted` | `Bool` | `false` for system containers (Inbox, Trash, Starred, Archive). |
| `isTrash` | `Bool` | This is the Trash folder. |
| `isInbox` | `Bool` | This is the Inbox folder. |
| `isStarred` | `Bool` | This is the Starred folder. |
| `isTag` | `Bool` | This is a tag (not a folder). |
| `isBuffer` | `Bool` | This is the hidden Buffer folder used for cut/paste. |
| `isAllNotes` | `Bool` | This is the All Notes system container. When selected, shows every non-trashed, non-buffered, non-archived note from all folders and tags. |
| `isArchive` | `Bool` | This is the Archive system container. Archived notes are hidden from All Notes and excluded from bulk search reindexing. |
| `colorRGBA` | `UInt32` | Packed RGBA color as 32-bit integer. Default: `0xFF26B9FF` (TakeNote pink). |
| `symbol` | `String` | SF Symbol name for display. Default: `"folder"`. |

### Computed Properties

- `notes: [Note]` — routes to `tagNotes`, `starredNotes`, or `folderNotes` based on flags.
- `isSystemFolder: Bool` — `true` if Trash, Inbox, Starred, All Notes, or Archive.

### System Containers

| Name | isInbox | isTrash | isStarred | isBuffer | isAllNotes | isArchive | canBeDeleted |
|---|---|---|---|---|---|---|---|
| Inbox | true | false | false | false | false | false | false |
| Trash | false | true | false | false | false | false | false |
| Starred | false | false | true | false | false | false | false |
| Buffer | false | false | false | true | false | false | false |
| All Notes | false | false | false | false | true | false | false |
| Archive | false | false | false | false | false | true | false |
| User folder | false | false | false | false | false | false | true |
| Tag | false | false | false | false | false | false | true |

### Key Methods

- `getSystemImageName() -> String` — returns filled/unfilled SF symbol based on content state.
- `getColor() -> Color` — decodes `colorRGBA` to SwiftUI `Color`. System folders always return `.takeNotePink`.
- `setColor(_ color: Color)` — encodes a SwiftUI `Color` into `colorRGBA`.

---

## NoteLink

**File:** `TakeNote/Models/NoteLink.swift`

A directed edge in the note graph. Created by `NoteLinkManager` when a note's content contains `takenote://note/<UUID>` links.

### Fields

| Field | Type | Description |
|---|---|---|
| `sourceNote` | `Note?` | The note containing the link. Inverse of `Note.outgoingLinks`. |
| `destinationNote` | `Note?` | The note being linked to. Inverse of `Note.incomingLinks`. |

NoteLink records are regenerated from scratch on every content change (old links for the source note are deleted, then new ones are created).

---

## NoteImage

**File:** `TakeNote/Models/NoteImage.swift`

Stores binary image data for images embedded in notes. Images are referenced from note content via the `![image](takenote://image/<UUID>)` Markdown pattern. `NoteImage` is intentionally freestanding — it has no SwiftData relationship to `Note`. Orphan culling is handled lazily by `NoteImageManager` (see `supporting-systems.md`).

### Fields

| Field | Type | Description |
|---|---|---|
| `imageUUID` | `UUID` | Stable identifier used in `takenote://image/<UUID>` URLs. `private(set)` — assigned once at creation; SwiftData internal hydration is the only permitted setter invocation after that. |
| `imageData` | `Data` | Raw binary image data (JPEG or PNG). CloudKit stores large `Data` fields as `CKAsset` automatically — no entitlement changes required. |
| `mimeType` | `String` | MIME type of the stored data. Either `"image/jpeg"` or `"image/png"`. |
| `createdDate` | `Date` | Creation timestamp. |

### Design Notes

- No `@Relationship` to `Note`. The link between a note and its images is purely textual: the note's `content` contains `takenote://image/<UUID>` references. This avoids SwiftData relationship complexity and allows images to outlive individual note edits until culled.
- `imageUUID` stability mirrors `Note.uuid`. It is the permanent cross-device identifier for this image record.

### Image Markdown Pattern

Images are embedded in note content using standard Markdown image syntax:

```
![image](takenote://image/<UUID>)
```

Where `<UUID>` is the `imageUUID` of the corresponding `NoteImage` record (e.g., `![image](takenote://image/550e8400-e29b-41d4-a716-446655440000)`).

`TakeNoteImageProvider` (a `MarkdownUI` image provider) resolves these URLs at render time by fetching the matching `NoteImage` record from the model context and displaying its `imageData`. If no matching record is found, the image renders as an empty view (graceful degradation).

### Orphan Culling

`NoteImageManager.cullOrphanedImages()` is responsible for removing `NoteImage` records that are no longer referenced by any active note's content. See `supporting-systems.md` for the full description of `NoteImageManager`.

### Designated Initializer

```swift
init(imageData: Data, mimeType: String)
```

Generates a fresh `UUID` for `imageUUID` and sets `createdDate = Date()`. The `mimeType` parameter should be `"image/jpeg"` for JPEG-encoded data and `"image/png"` for PNG fallback data.
