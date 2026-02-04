# State Management

TakeNote uses the Observable pattern with a central view model for app-wide state.

## TakeNoteVM

**File:** `TakeNoteVM.swift`

The main `@Observable` view model, marked `@MainActor` for thread safety.

### Core State

| Property | Type | Description |
|----------|------|-------------|
| `openNote` | `Note?` | Currently open note in editor |
| `selectedContainer` | `NoteContainer?` | Current folder/tag being viewed |
| `selectedNotes` | `Set<Note>` | Notes selected in note list |
| `languageModel` | `SystemLanguageModel` | Apple Foundation Models reference |

### System Container References

| Property | Purpose |
|----------|---------|
| `inboxFolder` | Inbox container |
| `trashFolder` | Trash container |
| `bufferFolder` | Hidden cut/paste buffer |
| `starredFolder` | Starred notes container |

### User Preferences (UserDefaults-backed)

| Property | Storage Key | Description |
|----------|-------------|-------------|
| `sortBy` | `SortBy` | Sort by created or updated date |
| `sortOrder` | `SortOrder` | Oldest or newest first |

### UI State

| Property | Description |
|----------|-------------|
| `emptyTrashAlertIsPresented` | Empty trash confirmation alert |
| `linkToNoteErrorIsPresented` | Deep link error alert |
| `folderSectionExpanded` | Sidebar folder section state |
| `tagSectionExpanded` | Sidebar tag section state |
| `errorAlertMessage` / `errorAlertIsVisible` | Generic error display |
| `showMultiNoteView` | Multi-note selection viewer |

### Computed Properties

| Property | Description |
|----------|-------------|
| `aiIsAvailable` | Whether Apple Intelligence is available |
| `canAddNote` | Can add note to current container |
| `canRenameSelectedContainer` | Can rename current container |
| `canEmptyTrash` | Trash selected and non-empty |
| `bufferIsEmpty` | Cut buffer has no notes |
| `bufferNotesCount` | Number of notes in cut buffer |
| `multipleNotesSelected` | More than one note selected |
| `trashFolderSelected` | Trash is current container |
| `navigationTitle` | "TakeNote" or "TakeNote (DEBUG)" |

### Key Methods

**Folder Management:**
- `addFolder(_ modelContext:)` - Create new folder
- `addTag(_ name:, color:, modelContext:)` - Create new tag
- `folderDelete(_ deletedFolder:, folders:, modelContext:)` - Delete folder, move notes to trash
- `folderInit(_ modelContext:)` - Create system folders on first launch

**Note Management:**
- `addNote(_ modelContext:) -> Note?` - Create note in selected container
- `moveNoteToTrash(_ noteToTrash:, modelContext:)` - Move to trash, unstar if starred
- `noteStarredToggle(_ note:, modelContext:)` - Toggle starred status
- `emptyTrash(_ modelContext:)` - Permanently delete all notes in trash

**Buffer Operations:**
- `moveNotesFromBufferToInbox(_ modelContext:)` - Move cut notes to inbox (paste fallback)

**Navigation:**
- `loadNoteFromURL(_ url:, modelContext:)` - Handle `takenote://note/{uuid}` deep links
- `onMoveToFolder()` - Clear selection after move
- `onNoteSelect(_ note:)` - Set open note
- `onTagDelete(_ deletedTag:)` - Handle tag deletion

## State Flow Patterns

### Note Selection Flow

1. User taps/clicks note in NoteList
2. `selectedNotes` updated via SwiftUI selection binding
3. `onChange(of: selectedNotes)` triggers in NoteList
4. For newly selected note: `vm.onNoteSelect(note)` called
5. For deselected notes:
   - `note.generateSummary()` triggered
   - `search.reindex(note:)` called
   - `NoteLinkManager.generateLinksFor(note:)` called

### Container Change Flow

1. User selects folder/tag in sidebar
2. `selectedContainer` updated
3. NoteList's `@Query` refetches filtered notes
4. `openNote` and `selectedNotes` may be cleared

### Delete Flow

1. User triggers delete (menu, swipe, keyboard)
2. CommandRegistry executes registered delete action
3. Note moved to trash via `moveNoteToTrash()`
4. If deleted note was selected, selection cleared
5. ModelContext saved

## Environment and FocusedValues

TakeNoteVM is injected via SwiftUI environment:

```swift
.environment(takeNoteVM)
```

Views access it with:

```swift
@Environment(TakeNoteVM.self) var vm
```

For menu commands and cross-view communication, FocusedValues are used. See [Command Pattern](command-pattern.md) for details.
