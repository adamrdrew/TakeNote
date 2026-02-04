# Quirks and Edge Cases

Non-obvious behaviors, workarounds, and implementation details.

## Data Model Quirks

### NoteIDWrapper Eager Snapshot

**File:** `Note.swift` (lines 28-32)

`NoteIDWrapper` eagerly encodes `PersistentIdentifier` to `Data` on initialization:

```swift
struct NoteIDWrapper: Hashable, Codable, Transferable {
    let id: PersistentIdentifier
    private let snapshot: Data  // eager bytes to avoid work-at-quit

    init(id: PersistentIdentifier) {
        self.id = id
        self.snapshot = (try? JSONEncoder().encode(id)) ?? Data()
    }
}
```

**Why:** Avoids SwiftData work during app termination. If encoding happened lazily during export, it could fail or cause issues when the app is quitting.

### NoteLink Inverse Specification

**File:** `NoteLink.swift` (lines 20-22)

Relationship inverses are specified on `NoteLink`, not on `Note`:

```swift
@Relationship(inverse: \Note.outgoingLinks) var source: Note?
@Relationship(inverse: \Note.incomingLinks) var destination: Note?
```

**Why:** Avoids Swift macro circularity issues that occur when both sides specify inverses.

### MD5 for Content Hashing

**File:** `Note.swift` (line 125)

Uses `Insecure.MD5` for content change detection:

```swift
let digest = Insecure.MD5.hash(data: content.data(using: .utf8)!)
```

**Why:** MD5 is fine for change detection (not security). It's fast and collision-resistant enough for this use case.

## AI Feature Quirks

### MagicFormatter Session Recreation

**File:** `MagicFormatter.swift` (lines 95-98)

Creates a new `LanguageModelSession` for each format request:

```swift
// Context window issues: Creating new session each time
// because cumulative context causes overflow on repeated reuse
let session = LanguageModelSession(instructions: MAGIC_FORMAT_PROMPT)
```

**Why:** Reusing sessions causes context window overflow. Each request needs a fresh session.

### Pseudo-Cancellation Pattern

**File:** `MagicFormatter.swift` (lines 49-65)

Apple's `LanguageModelSession` has no cancel API. Workaround:

```swift
func cancel() {
    sessionCancelled = true
    formatterIsBusy = false
}

// In format():
// After receiving response:
if sessionCancelled {
    throw MagicFormatterError.cancelled
}
```

**Why:** The session continues running, but the result is discarded. Views handle gracefully.

### Response Unwrapping

**File:** `UnwrapMarkdownFence.swift`

AI responses often wrapped in code fences. Must be stripped:

```swift
func unwrapMarkdownFence(_ text: String) -> String {
    // Removes ```...``` wrapper
    // Trims one trailing newline
}
```

**Why:** LLMs tend to wrap code/markdown in fences even when instructed not to.

## UI Quirks

### CommandRegistry Pattern

**File:** `Sidebar.swift` (lines 44-48, comment)

> "I think this is an utterly insane way to do this but I can't find a better way in SwiftUI to get list item actions to fire from the app menu."

**Why:** SwiftUI Lists get focus, but list items don't. Menu commands can't access row-specific closures. The registry pattern decouples commands from the view hierarchy.

### Buffer Folder for Cut/Paste

**File:** `NoteList.swift` (lines 136-141)

Cut notes are moved to a hidden "Buffer" folder:

```swift
// Cut: Move to buffer
note.folder = vm.bufferFolder

// Paste: Move from buffer
for note in vm.bufferFolder?.notes ?? [] {
    note.folder = destinationFolder
}

// Copy detection: If note NOT in buffer, it's a copy
```

**Why:** SwiftUI doesn't have native cut/paste for model objects. Buffer folder acts as clipboard.

### System Folder Color Enforcement

**File:** `SystemFolderReconciler.swift` (lines 54-57)

System folders always reset to specific color:

```swift
// Ensure system folder color
container.colorRGBA = 0xFF26B9FF
```

**Why:** Prevents user customization of system folders. Color is enforced during reconciliation.

### Vector Index Row ID Overflow

**File:** `VectorSearchIndex.swift` (line 136)

Uses wrapping arithmetic:

```swift
nextRowID &+= 1
```

**Why:** Handles integer overflow gracefully. Vector index is in-memory only, so row IDs can wrap.

## CloudKit Quirks

### DEBUG Schema Bootstrap

**File:** `AppBootstrapper.swift`

DEBUG builds manually push schema to CloudKit Development:

```swift
#if DEBUG
    AppBootstrapper.bootstrapDevSchemaIfNeeded(...)
#endif
```

**Why:** SwiftData's automatic schema migration doesn't always work with CloudKit. Manual bootstrap ensures schema is current.

### Duplicate System Folder Reconciliation

**File:** `SystemFolderReconciler.swift`

CloudKit sync can create duplicate Inbox/Trash folders:

```swift
// If duplicates exist, choose canonical (most notes, then lowest ID hash)
// Move notes from duplicates to canonical
// Delete duplicates
```

**Why:** Race condition when syncing between devices that both create system folders.

### Bootstrap Error Handling

**File:** `AppBootstrapper.swift` (lines 111-122)

Bootstrap ignores expected CloudKit errors:

```swift
// Network errors: transient
// Authentication errors: user not signed in
// Rate limiting: try again later
// Partial failures: some records failed
```

**Why:** These errors are expected during development/testing. Only unexpected errors are logged.

## Search Quirks

### Stopwords Include Contractions

**File:** `SearchIndex.swift` (lines 20-33)

Stopword list includes partial words:

```swift
"s", "t", "don"
```

**Why:** After splitting on apostrophes, contractions like "don't" become ["don", "t"]. These fragments should be filtered.

### Rate-Limited Full Reindex

**File:** `SearchIndexService.swift` (line 35)

Full reindex limited to once per 10 minutes:

```swift
func canReindexAllNotes() -> Bool {
    guard let last = lastFullReindex else { return true }
    return Date().timeIntervalSince(last) > 600
}
```

**Why:** CloudKit sync can trigger many rapid notifications. Rate limiting prevents excessive reindexing.

## Platform Quirks

### macOS Window vs WindowGroup

**File:** `TakeNoteApp.swift`

macOS uses `Window`, iOS uses `WindowGroup`:

```swift
#if os(macOS)
    Window("TakeNote", id: "main-window") { ... }
#else
    WindowGroup(id: "main-window") { ... }
#endif
```

**Why:** `Window` creates single-instance window (desired on macOS). `WindowGroup` required on iOS. Using `WindowGroup` on macOS causes undesired multi-window behavior.

### iPhone vs iPad Selection

**File:** `TakeNoteVM.swift` - `folderInit()`

iPhone starts with no selection:

```swift
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .pad {
        selectedContainer = inboxFolder
    }
    // iPhone: remains nil
#endif
```

**Why:** iPhone shows container list first (single-column navigation). iPad shows split view like macOS.

### Hardware Keyboard Detection

**File:** `NoteEditor.swift`

```swift
var hasHardwareKeyboard: Bool {
    GCKeyboard.coalesced != nil
}
```

**Why:** Hide on-screen markdown shortcuts when hardware keyboard connected. Uses GameController framework for detection.
