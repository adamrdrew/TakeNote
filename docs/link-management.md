# Link Management

TakeNote supports bidirectional linking between notes (backlinks).

## Overview

Notes can link to other notes using the `takenote://note/{uuid}` URL scheme. The system tracks these links bidirectionally, enabling backlink discovery.

## NoteLinkManager

**File:** `NoteLinkManager.swift`

### Core Operations

**`generateLinksFor(note:, modelContext:)`**

Extracts links from note content and creates `NoteLink` objects:

```swift
func generateLinksFor(note: Note, modelContext: ModelContext) {
    // 1. Extract UUIDs from markdown
    let uuids = extractNoteUUIDs(from: note.content)

    // 2. Delete existing outgoing links
    for link in note.outgoingLinks ?? [] {
        modelContext.delete(link)
    }

    // 3. Create new links
    for uuid in uuids {
        if let destinationNote = fetchNote(by: uuid, modelContext: modelContext) {
            let link = NoteLink()
            link.source = note
            link.destination = destinationNote
            modelContext.insert(link)
        }
    }

    try? modelContext.save()
}
```

**`extractNoteUUIDs(from:)`**

Parses markdown for `takenote://note/{uuid}` links:

```swift
// Case-insensitive UUID regex
let pattern = #"takenote://note/([0-9a-fA-F-]{36})"#
```

Returns deduplicated UUIDs in insertion order.

**`getNotesThatLinkTo(note:, modelContext:)`**

Find all notes that link to a given note (backlinks):

```swift
func getNotesThatLinkTo(note: Note, modelContext: ModelContext) -> [Note] {
    let links = getLinksForDestinationNote(note, modelContext: modelContext)
    return links.compactMap { $0.source }
}
```

### Query Methods

| Method | Returns |
|--------|---------|
| `getLinksForSourceNote(_:modelContext:)` | Links FROM this note |
| `getLinksForDestinationNote(_:modelContext:)` | Links TO this note |
| `getNotesThatLinkTo(_:modelContext:)` | Source notes (backlinks) |

## Integration Points

### Note Deselection

**File:** `NoteList.swift` (line 258)

When a note is deselected and content changed, links are regenerated:

```swift
.onChange(of: selectedNotes) { old, new in
    let deselected = old.subtracting(new)
    for note in deselected {
        Task {
            NoteLinkManager.generateLinksFor(note: note, modelContext: context)
        }
    }
}
```

### Backlinks View

**File:** `BackLinks.swift`

Displays notes that link to the current note:

```swift
struct BackLinks: View {
    let note: Note
    @State private var backlinks: [Note] = []

    var body: some View {
        List(backlinks) { linkedNote in
            // Navigate to linked note on tap
        }
        .task {
            backlinks = NoteLinkManager.getNotesThatLinkTo(
                note: note,
                modelContext: context
            )
        }
    }
}
```

### Editor Backlinks Toggle

**File:** `NoteEditor.swift`

Backlinks computed on note selection change:

```swift
.onChange(of: openNote) { _, note in
    guard let note = note else { return }
    let links = NoteLinkManager.getNotesThatLinkTo(note: note, modelContext: context)
    openNoteHasBacklinks = !links.isEmpty
}
```

Toolbar shows backlinks button when `openNoteHasBacklinks == true`.

## Creating Links

### Copy Markdown Link

**File:** `NoteListEntry.swift`

```swift
Button("Copy Markdown Link") {
    let link = note.getMarkdownLink()  // "[title](takenote://note/{uuid})"
    NSPasteboard.general.setString(link, forType: .string)
}
```

### Link Insertion

**File:** `NoteEditor.swift`

Insert link at cursor position:

```swift
func insertTextAtSelection(_ text: String) {
    // Get current position
    // Insert text
    // Reposition caret
}
```

## URL Format

```
takenote://note/{uuid}
```

- `uuid`: 36-character UUID string (case-insensitive)
- Example: `takenote://note/550e8400-e29b-41d4-a716-446655440000`

### Markdown Link Format

```markdown
[Note Title](takenote://note/550e8400-e29b-41d4-a716-446655440000)
```

## Deep Link Handling

**File:** `TakeNoteVM.swift` - `loadNoteFromURL(_:modelContext:)`

When app receives a `takenote://` URL:

1. Extract UUID from path
2. Query for matching note
3. Select note and navigate to its folder
4. Show error alert if note not found

```swift
func loadNoteFromURL(_ url: URL, modelContext: ModelContext) {
    guard let uuid = UUID(uuidString: url.lastPathComponent) else {
        linkToNoteErrorMessage = "Invalid note link"
        linkToNoteErrorIsPresented = true
        return
    }

    let notes = try? modelContext.fetch(
        FetchDescriptor<Note>(predicate: #Predicate { $0.uuid == uuid })
    )

    if let note = notes?.first {
        self.selectedNotes = [note]
        self.selectedContainer = note.folder
    }
}
```
