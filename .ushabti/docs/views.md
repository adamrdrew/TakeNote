# Views and Navigation

## Overview

TakeNote uses SwiftUI with a NavigationSplitView layout providing a three-column interface: sidebar (folders/tags), content (note list), and detail (note editor).

## Main Window

**File:** `/TakeNote/Views/MainWindow/MainWindow.swift`

The primary application window.

### Structure

```swift
NavigationSplitView(preferredCompactColumn: $preferredColumn) {
    // Sidebar: Folders and Tags
    Sidebar()
} content: {
    // Note List
    NoteList()
} detail: {
    // Note Editor or Multi-Note View
    if takeNoteVM.showMultiNoteView {
        MultiNoteViewer()
    } else {
        NoteEditor(openNote: $takeNoteVM.openNote)
    }
}
```

### Platform Adaptations

- **macOS:** Uses `Window` scene type (single instance)
- **iOS Phone:** Collapses to single column with navigation
- **iOS Tablet:** Full three-column layout

### Toolbar

Dynamic toolbar based on context:
- **Add Note** - When container allows new notes
- **Sort** - When container has notes (shows NoteSortPopover)
- **Chat** - When AI available and notes exist
- **Empty Trash** - When viewing non-empty trash

### URL Handling

```swift
.onOpenURL { url in
    takeNoteVM.loadNoteFromURL(url, modelContext: modelContext)
}
```

Handles `takenote://note/{uuid}` deep links.

## Sidebar

**File:** `/TakeNote/Views/MainWindow/Sidebar.swift`

Displays hierarchical list of folders and tags.

### Sections

1. **System Folders** - Inbox, Starred, Trash (always visible)
2. **User Folders** - Collapsible section
3. **Tags** - Collapsible section

### Features

- Drag-and-drop note reordering
- Inline rename via context menu
- Delete with confirmation
- Color picker for tags

## Note List

**File:** `/TakeNote/Views/NoteList/NoteList.swift`

Displays notes in the selected container.

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `NoteList` | `NoteList.swift` | Main list view with query |
| `NoteListEntry` | `NoteListEntry.swift` | Individual note row |
| `NoteListHeader` | `NoteListHeader.swift` | Container info header |

### Features

- SwiftData `@Query` with dynamic sorting
- Search filtering
- Multi-select support
- Swipe actions (delete, star)
- Context menu (move to folder, add tag)
- AI summary display (when available)

### Sorting

Uses `SortDescriptor` based on `TakeNoteVM.sortBy` and `sortOrder`:

```swift
@Query(sort: [SortDescriptor(\Note.updatedDate, order: .reverse)])
var notes: [Note]
```

## Note Editor

**File:** `/TakeNote/Views/NoteEditor/NoteEditor.swift`

Markdown editor with live preview.

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `NoteEditor` | `NoteEditor.swift` | Main editor view |
| `NoteEditorWindow` | `NoteEditorWindow.swift` | Standalone window wrapper |
| `BackLinks` | `BackLinks.swift` | Backlinks popover |

### Modes

1. **Preview Mode** - MarkdownUI rendered view (tap to edit)
2. **Edit Mode** - CodeEditorView with syntax highlighting

Toggle with toolbar button or Escape key.

### Editor Features

- **CodeEditorView** - Third-party Markdown editor with syntax highlighting
- **MarkdownUI** - Third-party Markdown renderer
- **Magic Format** - AI-powered formatting (toolbar button)
- **Magic Assistant** - Context-aware transformations (appears when text selected)
- **Backlinks** - Shows notes linking to current note

### iOS Adaptations

```swift
#if os(iOS)
.safeAreaInset(edge: .bottom) {
    if isInputActive && !showPreview && !hardwareKeyboardConnected {
        MarkdownShortcutBar(insert: insertAtCaret)
    }
}
#endif
```

On-screen keyboard shows Markdown shortcut bar when no hardware keyboard connected.

### MarkdownShortcutBar

Quick-insert buttons for common Markdown syntax:
- `#` - Heading
- `*` - Emphasis
- `1.` - Numbered list
- ``` ` ``` - Code fence
- `[]()` - Link

## Folder and Tag Lists

**Files:** `/TakeNote/Views/FolderList/`, `/TakeNote/Views/TagList/`

### FolderList / FolderListEntry

Renders folder items in sidebar with:
- System icon (tray/trash/star)
- Custom symbol for user folders
- Note count badge
- Drag-and-drop target for notes

### TagList / TagListEntry

Renders tag items in sidebar with:
- Tag icon (filled when has notes)
- Color indicator
- Editable name and color

### NoteContainerDetailsEditor

Popover for editing container properties:
- Name
- Symbol (SF Symbol picker)
- Color (for tags)

## Chat Window

**File:** `/TakeNote/Views/ChatWindow/ChatWindow.swift`

AI chat interface with RAG support.

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `ChatWindow` | `ChatWindow.swift` | Main chat view |
| `MessageBubble` | `MessageBubble.swift` | Chat message display |
| `ContextBubble` | `ContextBubble.swift` | Context preview bubble |

### Conversation Model

```swift
struct ConversationEntry: Identifiable {
    var id: UUID
    var sender: Sender  // .human or .bot
    var text: String
}
```

### Features

- Auto-scroll to latest message
- Typing indicator during generation
- New chat button
- Context display (for Magic Assistant mode)
- Clickable bot messages (for text replacement)

## Menu Commands

**Files:** `/TakeNote/Views/Commands/`

macOS menu bar commands using SwiftUI Commands API.

### FileCommands

- New Note (`Cmd+N`)
- New Folder
- New Tag
- Import Text Files
- Export Note

### EditCommands

- Magic Format (`Cmd+Shift+F`)
- Copy Note Link

### ViewCommands

- Toggle Preview (`Cmd+P`)
- Show Backlinks

### WindowCommands

- Open Chat Window (when AI available)

### FocusedValues

Commands communicate with views via FocusedValues:

```swift
extension FocusedValues {
    @Entry var togglePreview: (() -> Void)?
    @Entry var doMagicFormat: (() -> Void)?
    @Entry var textIsSelected: Bool?
    // ...
}
```

## Helper Views

**Files:** `/TakeNote/Views/Helpers/`

### AIMessage

Animated message with sparkle effect for AI operations:

```swift
AIMessage(message: "Thinking...", font: .headline)
```

### MultiNoteViewer

Displays when multiple notes are selected:
- Note count
- Bulk actions (move, delete, tag)

### NoteLabelBadge

Small badge showing note metadata (tag color, starred status).

## Welcome View

**Files:** `/TakeNote/Views/WelcomeMessage/`

Onboarding sheet shown on first launch:
- Feature highlights
- Get started button
- Version-gated (bumping `onboardingVersionCurrent` shows again)
