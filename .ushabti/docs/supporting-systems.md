# Supporting Systems

## Overview

This document covers the infrastructure, integration, and utility components that support the main application.

---

## AppBootstrapper

**File:** `TakeNote/Library/AppBootstrapper.swift`

A namespace struct containing all app initialization logic, keeping `TakeNoteApp` clean.

### makeModelConfiguration(debugStoreURL:)

Returns a `ModelConfiguration`. The `debugStoreURL` parameter is `@autoclosure`, evaluated only in DEBUG builds.

- **DEBUG:** `ModelConfiguration(url: debugStoreURL())` — uses the URL provided by the caller. In `TakeNoteApp`, this is `TakeNoteApp.debugStoreURL()`, which computes `~/Library/Application Support/TakeNoteDev/TakeNote.sqlite` (creating the directory if needed).
- **Release:** `ModelConfiguration()` — the default CloudKit-backed configuration.

### bootstrapDevSchemaIfNeeded(...) [DEBUG only]

Pushes the current SwiftData schema to the CloudKit **development** environment using a temporary `NSPersistentCloudKitContainer`. Only runs once per `ckBootstrapVersionCurrent` (version stored in `UserDefaults`). See `architecture.md` "CloudKit Schema Management" for the full workflow explanation.

The bootstrap function creates a temporary SQLite file (not the app's main store) to avoid interfering with the real SwiftData container. In `TakeNoteApp.init()`, this is a random-UUID file in the system temp directory: `FileManager.default.temporaryDirectory/CKBootstrap-<UUID>.sqlite`. The `storeURL` parameter receives this temp URL from the caller.

**Error handling:** Expected network errors (`CKError.networkUnavailable`, `.networkFailure`, `.serviceUnavailable`, `.notAuthenticated`, `.requestRateLimited`, `.internalError`) and Cocoa-domain errors are logged at `.info` level ("skipped due to expected condition") and swallowed. Unexpected errors are logged at `.warning` level. Neither causes a crash.

**Parameters:**
- `modelTypes: [any PersistentModel.Type]` — the model classes to include in the schema
- `storeURL: URL` — temporary SQLite URL for the bootstrap container (must NOT be the app's real store)
- `containerID: String` — CloudKit container ID (`"iCloud.com.adamdrew.takenote"`)
- `userDefaultsKey: String` — key to track schema version
- `currentVersion: Int` — current schema version number
- `logger: Logger` — logger for debug/info/warning output

### installReconciler(container:vm:runOnStartup:listenForLocalSaves:searchIndexService:)

Wires up the `SystemFolderReconciler` with notification observers. Returns a `ReconcilerHarness` (reconciler + observer tokens) that must be retained to keep observations alive.

- Listens for `NSPersistentStoreRemoteChange` — runs reconciler + bulk search reindex on CloudKit sync.
- Optionally listens for `NSManagedObjectContextDidSave` — the parameter default is `false`, but **in `TakeNoteApp.init()` it is called with `listenForLocalSaves: true`**. This means the reconciler runs on both remote changes AND every local save in production.
- Runs reconciler once on startup if `runOnStartup` is true (also `true` in the actual call).

The returned `ReconcilerHarness` holds the reconciler instance and notification observer tokens. It is stored in `TakeNoteApp.reconcilerHarness` (a `private var`). The tokens must be retained for the lifetime of the app to keep notifications active.

---

## SystemFolderReconciler

**File:** `TakeNote/Library/SystemFolderReconciler.swift`

`@MainActor`, `final class`.

CloudKit sync can create duplicate system folders (Inbox, Trash, Starred, Buffer) if the app runs on multiple devices. This class detects and merges duplicates.

### runOnce()

Reconciles all four system folder types. For each type:
1. Fetches all matching containers.
2. If system folder has wrong color (not `0xFF26B9FF`), corrects it and saves.
3. If only one exists, skips.
4. If multiple exist: picks a canonical (most notes, then lowest ID hash), moves all notes from duplicates to the canonical, updates `TakeNoteVM` if the selected container was a duplicate, deletes duplicates, saves.

After reconciliation, updates `TakeNoteVM`'s system folder references (`inboxFolder`, `trashFolder`, `bufferFolder`, `starredFolder`).

### chooseCanonical(from:)

Picks the container with the most notes. Tiebreaks by lowest `persistentModelID.hashValue`.

---

## SnapshotController

**File:** `TakeNote/Library/SnapshotController.swift`

Serializes app state to a JSON file shared with widget extensions via the App Group `group.TakeNote`.

### Snapshot Data Structures

```swift
struct NoteSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var uuid: UUID
    var title: String
    var excerpt: String  // the note's aiSummary
    var url: String      // takenote:// deep link
}

struct NoteContainerSnapshot: Codable, Identifiable, Hashable {
    var id: PersistentIdentifier
    var name: String
    var notes: [NoteSnapshot]    // top 5 most recently updated
    var symbol: String
    var color: UInt32
    var isInbox: Bool
    var isStarred: Bool
    var isTag: Bool
    var totalNoteCount: Int
}

struct Snapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var generatedAt: Date
    var containers: [NoteContainerSnapshot]
}
```

### takeSnapshot(modelContext:)

Fetches all containers, takes the top 5 most recently updated notes per container (skipping empty containers), builds the snapshot, writes it atomically to `group.TakeNote/snapshot.json`, and triggers `WidgetCenter.shared.reloadAllTimelines()`.

### readSnapshot() -> Snapshot?

Reads and decodes the snapshot file. Used by widget extensions via `ContainerProvider`.

### When Snapshots Are Taken

- App becomes active (`scenePhase == .active`)
- App goes inactive or background
- Every 10 minutes while active (via a cancellable `Task` loop in `TakeNoteApp`)

---

## NoteLinkManager

**File:** `TakeNote/Library/NoteLinkManager.swift`

`@MainActor`, `@Observable`.

Manages the `NoteLink` graph that tracks which notes link to which other notes via `takenote://note/<UUID>` URLs.

**Instantiation pattern:** Unlike `TakeNoteVM` and `SearchIndexService`, `NoteLinkManager` is **not** injected into the SwiftUI environment as a long-lived service. Instead, it is instantiated inline where needed:
- `NoteList.onChange(of: takeNoteVM.selectedNotes)` creates `NoteLinkManager(modelContext:)` on every note deselection to regenerate links.
- `NoteEditor.setShowBacklinks()` creates a fresh `NoteLinkManager(modelContext:)` to check if backlinks exist.

An agent extending the note link system should follow this inline instantiation pattern, not inject it as an environment object.

### generateLinksFor(_ note: Note)

Called when a note's content changes (on deselection in `NoteList`). Process:
1. Delete all existing `NoteLink` records where this note is the source.
2. Extract all `takenote://note/<UUID>` URLs from content via regex.
3. Fetch destination notes by UUID.
4. Create new `NoteLink` records for each resolved UUID.

### Query Methods

- `getNotesThatLinkTo(_ note: Note) -> [Note]` — source notes of all incoming links.
- `notesLinkToDestination(_ note: Note) -> Bool` — `true` if any notes link to this note (used to show/hide the backlinks toolbar button).

### URL Pattern

```
takenote://note/<UUID>
```

UUID format: `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` (case-insensitive).

---

## File Import

**File:** `TakeNote/Library/FileImport.swift`

Two `@MainActor` free functions for importing files as notes.

### fileImport(items:modelContext:searchIndex:folder:) -> ImportResult

Imports `.md` and `.txt` files. For each file:
- Reads UTF-8 content.
- Creates a `Note` in the target folder.
- Sets title to the filename.
- Calls `generateSummary()` and `searchIndex.reindex(note:)`.

Returns `ImportResult` with counts and error messages.

### folderImport(items:modelContext:searchIndex:) -> ImportResult

Imports a directory. For each dropped URL:
- Verifies it is a directory.
- Creates a new `NoteContainer` folder with the directory name.
- Calls `fileImport` for all non-directory children.

### ImportResult

```swift
struct ImportResult {
    var noteImportCount: Int
    var errorMessages: [String]
    var errorsEncountered: Bool   // computed
    var uniqueErrorMessages: [String]  // computed
    func toString() -> String
}
```

### Invocation Points

- `Sidebar` — accepts folder URL drops via `.dropDestination(for: URL.self)` → `folderImport`.
- `NoteList` — accepts file URL drops via `.dropDestination(for: URL.self)` → `fileImport` into the selected folder.

---

## AppIntents

**Files:** `TakeNote/AppIntents/NewNoteIntent.swift`, `NewNoteWithContentIntent.swift`

Siri/Shortcuts integration. Both intents open the app (`openAppWhenRun = true`) and access shared state via `AppDependencyManager`.

### NewNoteIntent

`static var title: "Create a new note"`

Creates a new note in the Inbox. Selects it in the UI.

### NewNoteWithContentIntent

`static var title: "Create a new note with content"`

Parameters:
- `content: String` — note body
- `noteTitle: String` — note title

Creates a note in Inbox, sets content and title via `note.setContent(content)` and `note.setTitle(noteTitle)` (the model's mutating methods, which update `updatedDate` and trigger `WidgetCenter.shared.reloadAllTimelines()`), then selects it in the UI.

### Dependency Access

Both intents use:
```swift
@Dependency(key: "ModelContainer") private var modelContainer: ModelContainer
@Dependency(key: "TakeNoteVM") private var takeNoteVM: TakeNoteVM
```

These keys are registered in `TakeNoteApp.init()` via `AppDependencyManager.shared.add(key:dependency:)`.

---

## Widgets and Control Extension

**Target:** `NewNoteControl`
**Files:** `NewNoteControl/`

### InboxWidget

`kind: "com.adamdrew.takenote.inboxWidget"`

Displays up to 5 recently updated notes from the Inbox container. Supports `.systemSmall`, `.systemMedium`, `.systemLarge`. Shows a "New Note" button (via `NewNoteIntent`).

### StarredWidget

`kind: "com.adamdrew.takenote.starredWidget"`

Same as InboxWidget but shows Starred notes. No new note button.

### NewNoteControl

`kind: "com.adamdrew.takenote.newNoteControl"`

A `ControlWidget` button for Control Center / Lock Screen that fires `NewNoteIntent`.

### ContainerProvider

Generic `TimelineProvider<NoteListEntry>` parameterized by a `ContainerSpec` protocol. `ContainerSpec` defines how to select a container from the shared `Snapshot`. Reads `Snapshot` via `SnapshotController.readSnapshot()`. Refreshes every 10 minutes when notes are present; retries every 45 seconds when no snapshot is available.

### NoteListEntry (widget entry)

```swift
struct NoteListEntry: TimelineEntry {
    var date: Date
    var rows: [NoteRow]
    var isPlaceholder: Bool
    var name: String
    var symbol: String
    var color: UInt32
    var totalNoteCount: Int
}
struct NoteRow {
    var id: UUID
    var title: String
    var excerpt: String
    var url: String
}
```

---

## Utility Library Files

### MarkdownConfiguration

**File:** `TakeNote/Library/MarkdownConfiguration.swift`

Extends `LanguageConfiguration` with a `markdown()` factory. Provides syntax highlighting rules for CodeEditorView: headings, emphasis, code fences, blockquotes, lists, links, tables, and task items. Custom `identifierRegex`, `operatorRegex`, and `numberRegex` patterns.

### TextFile

**File:** `TakeNote/Library/TextFile.swift`

A `FileDocument` implementation for note export. Stores `text: String`. Used by `.fileExporter` in `NoteListEntry` to save notes as `.md` files. `readableContentTypes = [UTType.plainText]`.

### FocusValues

**File:** `TakeNote/Library/FocusValues.swift`

Defines a `FocusedValueKey` for `ModelContext` so views can push their `modelContext` into `FocusedValues` for consumption by menubar commands.

```swift
extension FocusedValues {
    var modelContext: ModelContext? { get set }
}
```

### ChatFeatureFlagEnabled

**File:** `TakeNote/Library/ChatFeatureFlagEnabled.swift`

Global computed variable reading `MagicChatEnabled` from `Bundle.main.infoDictionary`. Returns `false` if the key is absent.
