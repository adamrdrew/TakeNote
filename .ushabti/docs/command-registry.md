# CommandRegistry Pattern

## Overview

`CommandRegistry` is a pattern that bridges SwiftUI menubar `Commands` (which live outside the view hierarchy) with operations that must execute inside specific list items. It solves a SwiftUI limitation: `List` items cannot directly expose `FocusedValues`, but the `List` itself can.

**File:** `TakeNote/Library/CommandRegistry.swift`

---

## The Problem

On macOS, menubar commands need to:
1. Know whether a rename/delete/etc. is currently possible (to enable/disable menu items).
2. Execute that operation on the correct list item (e.g., rename the selected folder, not just any folder).

The correct SwiftUI approach is `FocusedValues`. However, when a `List` has focus, its child items do not. This means child items cannot push their own closures into `FocusedValues`. The `List` can, but it does not know which item-level operations are available.

---

## The Solution

```
NoteList / Sidebar (List)
├── Holds CommandRegistry instances as @State
├── Injects them into environment (for list items to access)
├── Injects them into FocusedValues (for menubar commands to access)
└── NoteListEntry / FolderListEntry (List items)
    ├── On .onAppear: register their closures with the registry using their PersistentIdentifier
    └── On .onDisappear: unregister their closures
```

Menubar commands read the registries from `FocusedValues`. When they need to act, they call `registry.runCommand(id: selectedItem.id)`.

---

## CommandRegistry API

```swift
@Observable
internal final class CommandRegistry {
    func registerCommand(id: PersistentIdentifier, command: @escaping () -> Void)
    func unregisterCommand(id: PersistentIdentifier)
    func runCommand(id: PersistentIdentifier)
}
```

- `registerCommand(id:command:)` — binds a closure to a `PersistentIdentifier`.
- `unregisterCommand(id:)` — removes the binding (called on `.onDisappear`).
- `runCommand(id:)` — invokes the closure for the given ID, if registered.

All methods are `@MainActor`.

---

## Registries in Use

### Sidebar (folder/tag operations)

| Registry | Environment Key | FocusedValue Key | Operations |
|---|---|---|---|
| `containerDeleteRegistry` | `\.containerDeleteRegistry` | `\.containerDeleteRegistry` | Delete folder/tag |
| `containerRenameRegistry` | `\.containerRenameRegistry` | `\.containerRenameRegistry` | Rename folder/tag |
| `tagSetColorRegistry` | `\.tagSetColorRegistry` | `\.tagSetColorRegistry` | Open color picker for tag |

The selected container is also made available as `FocusedValue(\.selectedNoteContainer)` so that menubar commands know which ID to use.

### NoteList (note operations)

| Registry | Environment Key | FocusedValue Key | Operations |
|---|---|---|---|
| `noteDeleteRegistry` | `\.noteDeleteRegistry` | `\.noteDeleteRegistry` | Move note to Trash |
| `noteRenameRegistry` | `\.noteRenameRegistry` | `\.noteRenameRegistry` | Start inline rename |
| `noteStarToggleRegistry` | `\.noteStarToggleRegistry` | `\.noteStarToggleRegistry` | Toggle star |
| `noteCopyMarkdownLinkRegistry` | `\.noteCopyMarkdownLinkRegistry` | `\.noteCopyMarkdownLinkRegistry` | Copy Markdown link |
| `noteOpenEditorWindowRegistry` | `\.noteOpenEditorWindowRegistry` | `\.noteOpenEditorWindowRegistry` | Open detached editor window |

The selected notes set is also provided as `FocusedValue(\.selectedNotes)`.

---

## Environment Key Registration

Because there are multiple `CommandRegistry` instances of the same type in the environment, they are registered using custom `EnvironmentKey` structs (one per registry type) rather than by type:

```swift
private struct NoteDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
extension EnvironmentValues {
    var noteDeleteRegistry: CommandRegistry {
        get { self[NoteDeleteRegistryKey.self] }
        set { self[NoteDeleteRegistryKey.self] = newValue }
    }
}
```

This pattern is repeated for each registry.

---

## EditCommands Usage Example

`EditCommands` (menubar) reads registries and the selected container/notes from `FocusedValues`:

```swift
@FocusedValue(\.containerDeleteRegistry) var containerDeleteRegistry: CommandRegistry?
@FocusedValue(\.selectedNoteContainer) var selectedNoteContainer: NoteContainer?
```

When the Delete menu item is triggered:

```swift
if let sc = selectedNoteContainer, let rr = containerDeleteRegistry {
    rr.runCommand(id: sc.id)
}
```

This calls the `moveToTrash` closure registered by the `FolderListEntry` for that container's ID.

---

## Caveats

- Registries are populated only while list items are visible (on screen). Items scrolled out of view unregister their commands.
- This pattern is considered a workaround for a SwiftUI limitation. The codebase comment in `Sidebar.swift` describes this as "utterly insane" and notes that no official Apple guidance or community pattern exists for this problem.
- Any new list item that needs to respond to menubar commands must register/unregister with the appropriate registries in `.onAppear`/`.onDisappear`.
