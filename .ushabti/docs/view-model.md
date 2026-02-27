# View Model and Application State

## Overview

`TakeNoteVM` is the central application state object. It is `@Observable`, confined to `@MainActor`, and shared app-wide via the SwiftUI environment (`.environment(takeNoteVM)`). Every window that needs app state accesses it via `@Environment(TakeNoteVM.self)`.

**File:** `TakeNote/TakeNoteVM.swift`

---

## Enumerations

### SortBy

Controls which date field is used for note sorting.

```swift
enum SortBy: Int {
    case created = 0
    case updated = 1
}
```

### SortOrder

Controls ascending vs. descending sort direction.

```swift
enum SortOrder: Int {
    case oldestFirst = 0
    case newestFirst = 1
}
```

---

## State Properties

### Selection State

| Property | Type | Description |
|---|---|---|
| `openNote` | `Note?` | The note currently displayed in the editor. |
| `selectedContainer` | `NoteContainer?` | The folder or tag the user is viewing in the sidebar. |
| `selectedNotes` | `Set<Note>` | Notes selected in the note list (supports multi-select). |

### System Folder References

| Property | Type | Description |
|---|---|---|
| `inboxFolder` | `NoteContainer?` | Reference to the Inbox system folder. |
| `trashFolder` | `NoteContainer?` | Reference to the Trash system folder. |
| `bufferFolder` | `NoteContainer?` | Reference to the hidden Buffer folder used for cut/paste. |
| `starredFolder` | `NoteContainer?` | Reference to the Starred system folder. |
| `allNotesFolder` | `NoteContainer?` | Reference to the All Notes system container. |

### Search State

| Property | Type | Description |
|---|---|---|
| `searchQuery` | `String` | The current search query string. Bound to the `.searchable` modifier in `NoteList`. Empty string means no active search. |
| `searchIsActive` | `Bool` (computed) | `true` when `searchQuery` is non-empty. Drives FTS5 search path in `NoteList.filteredNotes` and BM25 short-circuit in `NoteList.sortedNotes`. |

### UI State

| Property | Type | Description |
|---|---|---|
| `emptyTrashAlertIsPresented` | `Bool` | Controls empty-trash confirmation alert. |
| `linkToNoteErrorIsPresented` | `Bool` | Controls note-link-error alert. |
| `linkToNoteErrorMessage` | `String` | Message for link error alert. |
| `folderSectionExpanded` | `Bool` | Folder section disclosure state in sidebar. |
| `tagSectionExpanded` | `Bool` | Tag section disclosure state in sidebar. |
| `errorAlertMessage` | `String` | Message for generic error alert. |
| `errorAlertIsVisible` | `Bool` | Controls generic error alert. |
| `showMultiNoteView` | `Bool` | When true, the detail column shows `MultiNoteViewer` instead of `NoteEditor`. |

### Sort Preferences

`sortBy` and `sortOrder` are custom `@Observable`-compatible computed properties that read/write to `UserDefaults` via `access(keyPath:)` and `withMutation(keyPath:)`. They are not directly `@AppStorage` so that they participate in the `@Observable` observation system.

### AI

| Property | Type | Description |
|---|---|---|
| `languageModel` | `SystemLanguageModel` | The Apple Intelligence system language model. Shared reference. |
| `aiIsAvailable` | `Bool` | Computed. `true` when `languageModel.availability == .available`. |

### Constants

| Constant | Value | Description |
|---|---|---|
| `inboxFolderName` | `"Inbox"` | Name of the Inbox system folder. |
| `trashFolderName` | `"Trash"` | Name of the Trash system folder. |
| `allNotesFolderName` | `"All Notes"` | Name of the All Notes system container. |
| `chatWindowID` | `"chat-window"` | SwiftUI window ID for the Chat window. |

---

## Computed Properties

| Property | Returns | Description |
|---|---|---|
| `canAddNote` | `Bool` | `true` if `selectedContainer` is not Trash, not a tag, not Starred, and not All Notes. |
| `canRenameSelectedContainer` | `Bool` | `true` if container is not Inbox, Trash, Starred, or All Notes. |
| `bufferIsEmpty` | `Bool` | `true` if Buffer folder has no notes. |
| `bufferNotesCount` | `Int` | Number of notes in Buffer folder. |
| `canEmptyTrash` | `Bool` | `true` if Trash is selected and not empty. |
| `inboxFolderExists` | `Bool` | `true` if `inboxFolder` is non-nil. |
| `multipleNotesSelected` | `Bool` | `true` if more than one note is selected. |
| `selectedContainerIsEmpty` | `Bool` | `true` if selected container has no notes. |
| `trashFolderSelected` | `Bool` | `true` if selected container is the Trash. |
| `navigationTitle` | `String` | `"TakeNote"` in release; `"TakeNote (DEBUG)"` in debug. |

---

## Methods

### Note Operations

- `addNote(_ modelContext: ModelContext) -> Note?` — creates a new `Note` in `selectedContainer`, inserts, saves, sets `openNote` and `selectedNotes`.
- `moveNoteToTrash(_ noteToTrash: Note, modelContext: ModelContext)` — moves a note to Trash, unsets `starred` if needed, clears selection if the note was selected.
- `emptyTrash(_ modelContext: ModelContext)` — permanently deletes all notes in Trash.
- `noteStarredToggle(_ note: Note, modelContext: ModelContext)` — toggles `note.starred` and updates `starredFolder.starredNotes`.
- `onNoteSelect(_ note: Note)` — sets `openNote`.
- `onMoveToFolder()` — clears `selectedNotes` and `openNote` after a move operation.
- `loadNoteFromURL(_ url: URL, modelContext: ModelContext)` — handles `takenote://note/<UUID>` deep links; finds and selects the note.

### Folder/Container Operations

- `addFolder(_ modelContext: ModelContext)` — creates a user folder and selects it.
- `addTag(_ name: String, color: Color, modelContext: ModelContext)` — creates a tag container.
- `folderDelete(_ deletedFolder: NoteContainer, folders: [NoteContainer], modelContext: ModelContext)` — moves all notes in folder to Trash, deletes folder, restores selection to Inbox.
- `onTagDelete(_ deletedTag: NoteContainer)` — clears selection if the deleted tag was selected.
- `folderInit(_ modelContext: ModelContext)` — creates system folders if not present, selects Inbox on startup (macOS) or if iPad.

### System Folder Creation (called by folderInit)

- `createInboxFolder(_:)`, `createTrashFolder(_:)`, `createBufferFolder(_:)`, `createStarredFolder(_:)`, `createAllNotesFolder(_:)` — idempotent; only creates if not already present.

### Buffer Operations

- `moveNotesFromBufferToInbox(_ modelContext: ModelContext)` — drains Buffer folder into Inbox. Called on app launch if Buffer is non-empty (handles crash recovery after a cut operation).

### Search Operations

- `activateSearch(query: String)` — guards `allNotesFolder` (no-op if nil), sets `selectedContainer = allNotesFolder`, sets `searchQuery = query`. Called by `NoteList` after debounce or on Return.
- `clearSearch()` — sets `searchQuery = ""`. Called by `NoteList` when the search bar is cleared. Does not change `selectedContainer`.

### Alert Control

- `showEmptyTrashAlert()` — sets `emptyTrashAlertIsPresented = true`.

---

## Dependency Injection for AppIntents

`TakeNoteVM` and `ModelContainer` are registered with `AppDependencyManager` in `TakeNoteApp.init()` using string keys `"TakeNoteVM"` and `"ModelContainer"`. This allows `AppIntent` implementations to retrieve them asynchronously on `@MainActor` without capturing `self`.
