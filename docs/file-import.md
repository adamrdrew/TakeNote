# File Import

TakeNote can import Markdown and plain text files.

## FileImport

**File:** `FileImport.swift`

### Supported Formats

- `.md` - Markdown files
- `.txt` - Plain text files

### Import Types

**Folder Import** - Import entire directory as a folder:

```swift
static func folderImport(
    urls: [URL],
    modelContext: ModelContext,
    inboxFolder: NoteContainer
) async -> ImportResult
```

**File Import** - Import individual files into existing folder:

```swift
static func fileImport(
    urls: [URL],
    folder: NoteContainer,
    modelContext: ModelContext
) async -> ImportResult
```

### Import Result

```swift
struct ImportResult {
    var noteImportCount: Int = 0
    var errorMessages: Set<String> = []
}
```

### Folder Import Process

1. Filter to directory URLs only
2. For each directory:
   - Create new `NoteContainer` with directory name
   - List contents and filter to `.md`/`.txt` files
   - Delegate to `fileImport()` for each file
3. Return combined results

### File Import Process

1. For each file URL:
   - Create new `Note` in target folder
   - Set title from filename (without extension)
   - Read file contents as UTF-8
   - Set note content
   - Trigger AI summary generation
   - Index in search service
2. Save ModelContext
3. Return results

### Error Handling

- Non-directory items rejected in folder import
- Only `.md`/`.txt` files processed
- File read errors captured in `errorMessages`
- Database save errors captured
- Errors deduplicated via Set

### Integration

**File menu command:**

```swift
// FileCommands.swift
Button("Import Files...") {
    // Show file picker
    // Call FileImport.fileImport()
}

Button("Import Folder...") {
    // Show folder picker
    // Call FileImport.folderImport()
}
```

### Post-Import Actions

After successful import:

1. `note.generateSummary()` - Queue AI summary generation
2. `search.reindex(note:)` - Add to search index
3. Widget timelines reloaded (via Note setters)

## Example Usage

```swift
let result = await FileImport.fileImport(
    urls: selectedFileURLs,
    folder: vm.selectedContainer ?? vm.inboxFolder!,
    modelContext: modelContext
)

if result.noteImportCount > 0 {
    print("Imported \(result.noteImportCount) notes")
}

for error in result.errorMessages {
    print("Error: \(error)")
}
```
