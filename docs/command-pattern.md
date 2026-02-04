# Command Pattern

TakeNote uses a CommandRegistry pattern to connect menu commands with list item actions.

## The Problem

SwiftUI Lists receive focus, but individual list items (rows) do not. Menu commands need to execute actions on specific items (delete a folder, rename a note), but can't access row-specific closures directly.

## The Solution

**File:** `CommandRegistry.swift`

```swift
@Observable
class CommandRegistry<Key: Hashable> {
    private var commands: [Key: () -> Void] = [:]

    func register(key: Key, action: @escaping () -> Void)
    func unregister(key: Key)
    func run(key: Key)
}
```

### Pattern Flow

1. **Sidebar/NoteList creates registries** as `@State` properties
2. **Registries stored as FocusedValues** for menu access
3. **List items register actions** on appear, unregister on disappear
4. **Menu commands retrieve registries** and execute by ID

## Implementation

### Registry Creation

**File:** `Sidebar.swift` (lines 113-115)

```swift
@State private var containerDeleteRegistry = CommandRegistry<PersistentIdentifier>()
@State private var containerRenameRegistry = CommandRegistry<PersistentIdentifier>()
```

**File:** `NoteList.swift` (lines 67-71)

```swift
@State private var noteDeleteRegistry = CommandRegistry<PersistentIdentifier>()
@State private var noteRenameRegistry = CommandRegistry<PersistentIdentifier>()
@State private var noteStarToggleRegistry = CommandRegistry<PersistentIdentifier>()
@State private var noteCopyMarkdownLinkRegistry = CommandRegistry<PersistentIdentifier>()
@State private var noteOpenEditorWindowRegistry = CommandRegistry<PersistentIdentifier>()
```

### Focused Values Definition

**File:** `Sidebar.swift` (lines 52-83)

```swift
extension FocusedValues {
    @Entry var containerDeleteRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var containerRenameRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var selectedNoteContainer: NoteContainer?
    @Entry var tagSetColorRegistry: CommandRegistry<PersistentIdentifier>?
}
```

**File:** `NoteList.swift` (lines 12-57)

```swift
extension FocusedValues {
    @Entry var noteDeleteRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var noteRenameRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var noteStarToggleRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var noteCopyMarkdownLinkRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var noteOpenEditorWindowRegistry: CommandRegistry<PersistentIdentifier>?
    @Entry var selectedNotes: Set<Note>?
}
```

### Registration in List Items

**File:** `FolderListEntry.swift` (lines 125-142)

```swift
.onAppear {
    containerDeleteRegistry?.register(key: container.persistentModelID) {
        deleteFolder()
    }
    containerRenameRegistry?.register(key: container.persistentModelID) {
        isRenaming = true
    }
}
.onDisappear {
    containerDeleteRegistry?.unregister(key: container.persistentModelID)
    containerRenameRegistry?.unregister(key: container.persistentModelID)
}
```

**File:** `NoteListEntry.swift` (lines 501-533)

```swift
.onAppear {
    noteDeleteRegistry?.register(key: note.persistentModelID) {
        vm.moveNoteToTrash(note, modelContext: modelContext)
    }
    noteRenameRegistry?.register(key: note.persistentModelID) {
        isRenaming = true
    }
    noteStarToggleRegistry?.register(key: note.persistentModelID) {
        vm.noteStarredToggle(note, modelContext: modelContext)
    }
    // ... more registrations
}
.onDisappear {
    noteDeleteRegistry?.unregister(key: note.persistentModelID)
    // ... more unregistrations
}
```

### Menu Command Usage

**File:** `EditCommands.swift`

```swift
struct EditCommands: Commands {
    @FocusedValue(\.noteDeleteRegistry) var noteDeleteRegistry
    @FocusedValue(\.selectedNotes) var selectedNotes

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Delete Note") {
                guard let notes = selectedNotes else { return }
                for note in notes {
                    noteDeleteRegistry?.run(key: note.persistentModelID)
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(selectedNotes?.isEmpty ?? true)
        }
    }
}
```

## FocusedValues by View

### From Sidebar

| Key | Type | Description |
|-----|------|-------------|
| `containerDeleteRegistry` | `CommandRegistry<PersistentIdentifier>?` | Delete folder/tag |
| `containerRenameRegistry` | `CommandRegistry<PersistentIdentifier>?` | Rename folder/tag |
| `selectedNoteContainer` | `NoteContainer?` | Currently selected container |
| `tagSetColorRegistry` | `CommandRegistry<PersistentIdentifier>?` | Set tag color |

### From NoteList

| Key | Type | Description |
|-----|------|-------------|
| `noteDeleteRegistry` | `CommandRegistry<PersistentIdentifier>?` | Delete note |
| `noteRenameRegistry` | `CommandRegistry<PersistentIdentifier>?` | Rename note |
| `noteStarToggleRegistry` | `CommandRegistry<PersistentIdentifier>?` | Toggle star |
| `noteCopyMarkdownLinkRegistry` | `CommandRegistry<PersistentIdentifier>?` | Copy link |
| `noteOpenEditorWindowRegistry` | `CommandRegistry<PersistentIdentifier>?` | Open in window |
| `selectedNotes` | `Set<Note>?` | Currently selected notes |

### From NoteEditor

| Key | Type | Description |
|-----|------|-------------|
| `togglePreview` | `(() -> Void)?` | Toggle edit/preview |
| `doMagicFormat` | `(() -> Void)?` | Run Magic Format |
| `textIsSelected` | `Bool` | Text selection exists |
| `showAssistantPopover` | `Binding<Bool>?` | Show Magic Assistant |
| `showBacklinks` | `Binding<Bool>?` | Show backlinks panel |
| `openNoteHasBacklinks` | `Bool` | Note has backlinks |

### From MainWindow

| Key | Type | Description |
|-----|------|-------------|
| `chatEnabled` | `Bool` | Chat feature available |
| `openChatWindow` | `(() -> Void)?` | Open chat window |
| `showDeleteEverything` | `Binding<Bool>?` | Debug delete all |

## Design Notes

From `Sidebar.swift` comment (lines 44-48):

> "I think this is an utterly insane way to do this but I can't find a better way in SwiftUI to get list item actions to fire from the app menu."

The pattern works but adds complexity. It's a workaround for SwiftUI's focus model limitations.

## Benefits

1. **Decouples menu commands from view hierarchy** - Commands don't need direct references to views
2. **Supports multi-selection** - Iterate over selected items and run commands
3. **Dynamic registration** - Only visible items have registered actions
4. **Type-safe keys** - Uses `PersistentIdentifier` for uniqueness
