# Note Editor

The note editor provides Markdown editing with syntax highlighting and preview.

## Architecture

**Files:** `NoteEditor.swift`, `NoteEditorWindow.swift`

### Components

- **CodeEditor** - Third-party library for syntax-highlighted editing
- **MarkdownUI** - Renders Markdown as formatted text
- **Magic Format** - AI-powered formatting
- **Magic Assistant** - AI help for selected text
- **Backlinks Panel** - Notes linking to current note

## Dual Mode

The editor has two modes toggled via toolbar button or keyboard:

### Edit Mode

Uses `CodeEditor` from CodeEditorView library:

```swift
CodeEditor(
    text: $content,
    position: $editorPosition,
    language: .markdown(),
    theme: theme,
    layout: layout
)
```

**Configuration in `MarkdownConfiguration.swift`:**
- Syntax patterns for headings, lists, code, emphasis
- Token highlighting for `TODO`, `NOTE`, `WARNING`, `HACK`, `FIXME`

### Preview Mode

Uses `Markdown` view from MarkdownUI:

```swift
ScrollView {
    Markdown(content)
        .markdownTheme(.gitHub)
}
```

Tapping/clicking toggles back to edit mode.

## Position Tracking

```swift
@State private var editorPosition = CodeEditor.Position()
```

Tracks:
- Cursor location (line, column)
- Selection range (if any)
- Scroll position

Used for:
- Text insertion at cursor
- Selection replacement (Magic Format, Magic Assistant)

## Text Operations

### Insert at Cursor

```swift
func insertTextAtSelection(_ text: String) {
    guard let note = openNote else { return }

    // Get NSRange from editor position
    let range = editorPosition.range ?? NSRange(location: content.count, length: 0)

    // Convert to String.Index range
    guard let stringRange = Range(range, in: content) else { return }

    // Replace range with new text
    var newContent = content
    newContent.replaceSubrange(stringRange, with: text)
    note.setContent(newContent)

    // Reposition caret after insertion
    let newLocation = range.location + text.count
    editorPosition = CodeEditor.Position(
        range: NSRange(location: newLocation, length: 0)
    )
}
```

### Replace Selection

```swift
func replaceSelection(with replacement: String) {
    guard let range = editorPosition.range,
          let stringRange = Range(range, in: content) else { return }

    var newContent = content
    newContent.replaceSubrange(stringRange, with: replacement)
    note?.setContent(newContent)
}
```

## Magic Format Integration

**File:** `NoteEditor.swift` (lines 134-164)

### Process

1. Hash input content before formatting
2. Set `formatterIsBusy = true`
3. Call `magicFormatter.format(content)`
4. On response:
   - Verify input hash matches (detect racing changes)
   - Replace content with formatted result
5. Handle errors/cancellation gracefully

### State

```swift
@State private var magicFormatter = MagicFormatter()
```

### Controls

- Disabled during formatting (`formatterIsBusy`)
- Cancel button shown while processing
- Error display if formatting fails

## Magic Assistant Integration

**File:** `NoteEditor.swift` (lines 399-430)

Appears when text is selected:

```swift
.popover(isPresented: $showAssistantPopover) {
    if textIsSelected {
        ChatWindow(
            context: selectedText,
            instructions: MAGIC_ASSISTANT_PROMPT,
            searchEnabled: false,
            useHistory: false,
            onBotMessageClick: { replacement in
                replaceSelection(with: replacement)
                showAssistantPopover = false
            }
        )
    }
}
```

### Selection Detection

```swift
var textIsSelected: Bool {
    guard let range = editorPosition.range else { return false }
    return range.length > 0
}

var selectedText: String {
    guard let range = editorPosition.range,
          let stringRange = Range(range, in: content) else { return "" }
    return String(content[stringRange])
}
```

## Backlinks Panel

**File:** `BackLinks.swift`

Shows notes that link to the current note.

### Computation

```swift
.onChange(of: openNote) { _, note in
    guard let note = note else {
        openNoteHasBacklinks = false
        return
    }

    let links = NoteLinkManager.getNotesThatLinkTo(
        note: note,
        modelContext: modelContext
    )
    openNoteHasBacklinks = !links.isEmpty
}
```

### Toggle

Toolbar button visible when `openNoteHasBacklinks == true`:

```swift
if openNoteHasBacklinks {
    Button {
        showBacklinks.toggle()
    } label: {
        Image(systemName: "link")
    }
}
```

## iOS Markdown Shortcuts

**File:** `NoteEditor.swift` (lines 328-339)

Bottom toolbar with common Markdown insertions:

```swift
.safeAreaInset(edge: .bottom) {
    if inputFocused && !isPreviewing && !hasHardwareKeyboard {
        HStack {
            Button("# ") { insert("# ") }
            Button("**") { insert("**") }
            Button("*") { insert("*") }
            Button("- ") { insert("- ") }
            Button("`") { insert("`") }
            Button("[](") { insert("[](") }
        }
    }
}
```

Hidden when:
- Not editing (previewing)
- Input not focused
- Hardware keyboard detected

## Platform Differences

### macOS

- Escape key exits preview mode
- Double-click opens separate editor window
- Hardware keyboard assumed

### iOS

- Tap anywhere toggles preview
- Markdown shortcuts toolbar
- Hardware keyboard detection:

```swift
var hasHardwareKeyboard: Bool {
    GCKeyboard.coalesced != nil
}
```

## Separate Editor Window (macOS)

**File:** `NoteEditorWindow.swift`

Opens note in standalone window:

```swift
WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) { noteID in
    NoteEditorWindow(noteID: noteID)
}
```

Accessed via:
- Double-click note in list
- Menu: Window > Open in New Window
- Keyboard shortcut

Note resolved from `NoteIDWrapper`:

```swift
@Query var notes: [Note]

init(noteID: Binding<NoteIDWrapper?>) {
    if let id = noteID.wrappedValue?.id {
        _notes = Query(filter: #Predicate { $0.persistentModelID == id })
    }
}
```
