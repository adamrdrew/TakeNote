# View Model and State Management

## Overview

`TakeNoteVM` is the central state container for the application, implemented as an `@Observable @MainActor` class. It manages UI state, selection, and provides CRUD operations for notes and containers.

**File:** `/TakeNote/TakeNoteVM.swift`

## State Properties

### Selection State

| Property | Type | Description |
|----------|------|-------------|
| `openNote` | `Note?` | Currently open note in the editor |
| `selectedContainer` | `NoteContainer?` | Active folder or tag in sidebar |
| `selectedNotes` | `Set<Note>` | Selected notes in the note list |

### System Folders

| Property | Type | Description |
|----------|------|-------------|
| `inboxFolder` | `NoteContainer?` | Reference to Inbox container |
| `trashFolder` | `NoteContainer?` | Reference to Trash container |
| `bufferFolder` | `NoteContainer?` | Reference to Buffer container |
| `starredFolder` | `NoteContainer?` | Reference to Starred container |

### UI State

| Property | Type | Description |
|----------|------|-------------|
| `emptyTrashAlertIsPresented` | `Bool` | Empty trash confirmation dialog |
| `linkToNoteErrorIsPresented` | `Bool` | Link error alert visibility |
| `linkToNoteErrorMessage` | `String` | Link error message text |
| `folderSectionExpanded` | `Bool` | Sidebar folder section state |
| `tagSectionExpanded` | `Bool` | Sidebar tag section state |
| `errorAlertMessage` | `String` | General error message |
| `errorAlertIsVisible` | `Bool` | Error alert visibility |
| `showMultiNoteView` | `Bool` | Multi-note selection mode |

### Sorting

Sorting preferences persist to UserDefaults:

```swift
enum SortBy: Int {
    case created = 0
    case updated = 1
}

enum SortOrder: Int {
    case oldestFirst = 0
    case newestFirst = 1
}

var sortBy: SortBy      // Persisted to "SortBy" key
var sortOrder: SortOrder // Persisted to "SortOrder" key
```

### AI Integration

```swift
let languageModel = SystemLanguageModel.default

var aiIsAvailable: Bool {
    return languageModel.availability == .available
}
```

## Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `canAddNote` | `Bool` | True if selected container allows new notes |
| `canRenameSelectedContainer` | `Bool` | True if selected container is user-created |
| `bufferIsEmpty` | `Bool` | True if buffer folder has no notes |
| `bufferNotesCount` | `Int` | Number of notes in buffer |
| `canEmptyTrash` | `Bool` | True if trash is selected and not empty |
| `inboxFolderExists` | `Bool` | True if inbox folder is assigned |
| `multipleNotesSelected` | `Bool` | True if more than one note selected |
| `selectedContainerIsEmpty` | `Bool` | True if selected container has no notes |
| `trashFolderSelected` | `Bool` | True if trash is selected |
| `navigationTitle` | `String` | "TakeNote" or "TakeNote (DEBUG)" |

## CRUD Methods

### Folder Operations

```swift
func addFolder(_ modelContext: ModelContext)
// Creates new folder, saves, sets as selected

func folderDelete(
    _ deletedFolder: NoteContainer,
    folders: [NoteContainer],
    modelContext: ModelContext
)
// Moves notes to trash, deletes folder, updates selection

func folderInit(_ modelContext: ModelContext)
// Creates system folders if missing, sets initial selection
```

### Note Operations

```swift
func addNote(_ modelContext: ModelContext) -> Note?
// Creates note in selected folder, sets as open and selected

func moveNoteToTrash(_ noteToTrash: Note, modelContext: ModelContext)
// Moves note to trash folder, clears starred status

func moveNotesFromBufferToInbox(_ modelContext: ModelContext)
// Moves all buffer notes back to inbox

func noteStarredToggle(_ note: Note, modelContext: ModelContext)
// Toggles starred status, manages starredNotes relationship
```

### Tag Operations

```swift
func addTag(
    _ name: String = "New Tag",
    color: Color = .takeNotePink,
    modelContext: ModelContext
)
// Creates new tag, saves, sets as selected

func onTagDelete(_ deletedTag: NoteContainer)
// Updates selection if deleted tag was selected
```

### System Folder Creation

```swift
func createInboxFolder(_ modelContext: ModelContext)
func createTrashFolder(_ modelContext: ModelContext)
func createBufferFolder(_ modelContext: ModelContext)
func createStarredFolder(_ modelContext: ModelContext)
```

Each method creates the respective system folder if it doesn't exist and assigns it to the corresponding property.

### Trash Operations

```swift
func emptyTrash(_ modelContext: ModelContext)
// Permanently deletes all notes in trash

func showEmptyTrashAlert()
// Shows confirmation dialog
```

## Navigation Methods

```swift
func loadNoteFromURL(_ url: URL, modelContext: ModelContext)
// Handles takenote://note/{uuid} deep links
// Fetches note by UUID, sets selection and container

func onMoveToFolder()
// Clears selection after folder move

func onNoteSelect(_ note: Note)
// Sets openNote when note is selected
```

## Environment Integration

The view model is distributed through the environment:

```swift
// In TakeNoteApp
MainWindow()
    .environment(takeNoteVM)
    .focusedSceneValue(takeNoteVM)

// In views
@Environment(TakeNoteVM.self) var takeNoteVM
```

## AppIntents Integration

The view model is registered with `AppDependencyManager` for Siri/Shortcuts:

```swift
AppDependencyManager.shared.add(
    key: "TakeNoteVM",
    dependency: { @MainActor in viewModel }
)
```

This allows `AppIntent` implementations to access the view model via `@Dependency(key: "TakeNoteVM")`.
