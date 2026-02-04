# View Hierarchy

TakeNote uses SwiftUI with a multi-column navigation structure.

## App Structure

**File:** `TakeNoteApp.swift`

```
TakeNoteApp
├── MainSceneCore (Window on macOS, WindowGroup on iOS)
│   └── MainWindow
│       ├── Sidebar
│       │   ├── FolderList
│       │   └── TagList
│       └── NoteList
│           └── NoteEditor (or MultiNoteViewer)
│
├── WindowGroup("note-editor-window") [macOS only]
│   └── NoteEditorWindow
│
└── WindowGroup("chat-window")
    └── ChatWindow
```

## Main Window

**File:** `MainWindow.swift`

Three-column NavigationSplitView:

```swift
NavigationSplitView {
    Sidebar()  // Column 1: Folders and Tags
} content: {
    NoteList()  // Column 2: Notes in selected container
} detail: {
    if showMultiNoteView {
        MultiNoteViewer()
    } else {
        NoteEditor()  // Column 3: Editor
    }
}
```

### Platform Differences

**macOS:** Uses `Window` scene for single-instance main window.

**iOS:** Uses `WindowGroup` for multiple windows on iPad.

```swift
private var MainSceneCore: some Scene {
    #if os(macOS)
        Window("TakeNote", id: "main-window") {
            MainAppWindow
        }
    #else
        WindowGroup(id: "main-window") {
            MainAppWindow
        }
    #endif
}
```

## Sidebar

**File:** `Sidebar.swift`

Two expandable sections:

1. **Folders Section** - System folders (Inbox, Starred, Trash) + user folders
2. **Tags Section** - User-created tags

### Folder List

**File:** `FolderList.swift`, `FolderListEntry.swift`

- Displays all non-tag containers
- System folders pinned at top
- Supports rename, delete (user folders only)
- Drag-and-drop notes onto folders

### Tag List

**File:** `TagList.swift`, `TagListEntry.swift`

- Displays all tag containers
- Color picker and icon picker
- Supports rename, delete, color change

## Note List

**File:** `NoteList.swift`, `NoteListEntry.swift`, `NoteListHeader.swift`

### Query

```swift
@Query var notes: [Note]

init(container: NoteContainer?) {
    let containerID = container?.persistentModelID
    _notes = Query(
        filter: #Predicate<Note> { $0.folder?.persistentModelID == containerID },
        sort: [SortDescriptor(\.updatedDate, order: .reverse)]
    )
}
```

### Features

- Selection (single or multi-select)
- Swipe actions (iOS): delete, star
- Context menu: delete, star, move, copy link
- Sort options (created/updated, ascending/descending)
- Search bar (FTS5 + toolbar integration)

### Cut/Copy/Paste

**Buffer folder** used for cut operations:
- Cut: Move notes to buffer
- Paste: Move from buffer to destination
- Copy detection: If note not in buffer, it's a copy

## Note Editor

**File:** `NoteEditor.swift`, `NoteEditorWindow.swift`

### Dual Mode

- **Edit mode:** CodeEditor with Markdown syntax highlighting
- **Preview mode:** MarkdownUI rendered view

Toggle via toolbar button or keyboard shortcut.

### Features

- Magic Format button (AI formatting)
- Magic Assistant popover (on text selection)
- Backlinks panel
- Title editing
- Markdown shortcuts toolbar (iOS)

### Separate Window (macOS)

Double-click note or use menu to open in separate window:

**File:** `NoteEditorWindow.swift`

```swift
WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) { noteID in
    NoteEditorWindow(noteID: noteID)
}
```

## Chat Window

**File:** `ChatWindow.swift`, `MessageBubble.swift`, `ContextBubble.swift`

Standalone chat interface with RAG support.

### Components

- Message list (human/bot bubbles)
- Context display (optional)
- Input field
- Search toggle

### Integration Modes

**Standalone:** Full-screen chat window with search enabled.

**Embedded:** Assistant popover in editor with context and no search.

## Helper Views

**Directory:** `Views/Helpers/`

| View | Purpose |
|------|---------|
| `AIMessage.swift` | AI response display component |
| `MultiNoteViewer.swift` | View multiple selected notes |
| `NoteLabelBadge.swift` | Tag badge display |

## Commands

**Directory:** `Views/Commands/`

Menu bar commands for each menu:

| File | Menu |
|------|------|
| `FileCommands.swift` | File menu (new note, import, export) |
| `EditCommands.swift` | Edit menu (delete, rename, Magic Format) |
| `ViewCommands.swift` | View menu (preview toggle, sort) |
| `WindowCommands.swift` | Window menu (chat, separate editor) |

Commands use FocusedValues to access current view state. See [Command Pattern](command-pattern.md).

## Onboarding

**Files:** `WelcomeView.swift`, `WelcomeRow.swift`

Shown on first launch or after version bump:

```swift
private let onboardingVersionCurrent = 3
```

Displays feature overview with icons and descriptions.
