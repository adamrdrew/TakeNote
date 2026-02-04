# URL Scheme

TakeNote uses a custom URL scheme for deep linking to notes.

## Format

```
takenote://note/{uuid}
```

- **Scheme:** `takenote`
- **Host:** `note`
- **Path:** UUID of the note (36-character string)

## Examples

```
takenote://note/550e8400-e29b-41d4-a716-446655440000
takenote://note/6ba7b810-9dad-11d1-80b4-00c04fd430c8
```

## Markdown Link Format

Notes can link to each other using markdown:

```markdown
[Note Title](takenote://note/550e8400-e29b-41d4-a716-446655440000)
```

## Registration

**File:** `TakeNote/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.adamdrew.takenote</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>takenote</string>
        </array>
    </dict>
</array>
```

## Handling

**File:** `TakeNoteApp.swift`

App registers for external events:

```swift
.handlesExternalEvents(matching: ["takenote://"])
```

**File:** `TakeNoteVM.swift` - `loadNoteFromURL(_:modelContext:)`

```swift
func loadNoteFromURL(_ url: URL, modelContext: ModelContext) {
    // Extract UUID from path
    guard let uuid = UUID(uuidString: url.lastPathComponent) else {
        linkToNoteErrorMessage = "Invalid note link"
        linkToNoteErrorIsPresented = true
        return
    }

    // Query for note
    let notes = try? modelContext.fetch(
        FetchDescriptor<Note>(
            predicate: #Predicate { $0.uuid == uuid }
        )
    )

    // Navigate to note
    if let note = notes?.first {
        self.selectedNotes = [note]
        self.selectedContainer = note.folder
        return
    }

    // Show error if not found
    linkToNoteErrorMessage = "No notes matching link found"
    linkToNoteErrorIsPresented = true
}
```

## Error Handling

| Error | Message |
|-------|---------|
| Invalid UUID format | "Invalid note link" |
| Note not found | "No notes matching link found" |
| Query failure | "Error querying notes." |
| Unknown error | "Something went wrong setting note from link" |

Errors displayed via alert bound to `linkToNoteErrorIsPresented`.

## Generating Links

### Get URL String

```swift
// Note.swift
func getURL() -> String {
    return "takenote://note/\(uuid.uuidString)"
}
```

### Get Markdown Link

```swift
// Note.swift
func getMarkdownLink() -> String {
    return "[\(title)](\(getURL()))"
}
```

### Copy to Clipboard

**File:** `NoteListEntry.swift`

```swift
Button("Copy Markdown Link") {
    let link = note.getMarkdownLink()
    #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    #else
        UIPasteboard.general.string = link
    #endif
}
```

## Widget Integration

**File:** `NoteContainerWidgetView.swift`

Widgets use deep links to open specific notes:

```swift
Link(destination: URL(string: "takenote://note/\(note.id)")!) {
    NoteRow(note: note)
}
```

## Link Extraction

**File:** `NoteLinkManager.swift`

Regex pattern for extracting links from content:

```swift
let pattern = #"takenote://note/([0-9a-fA-F-]{36})"#
```

- Case-insensitive UUID matching
- Captures UUID group for note lookup
- Used for generating backlinks
