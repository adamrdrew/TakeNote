# Architecture Overview

## Overview

TakeNote is a native Markdown note-taking app for macOS and iOS (with visionOS compilation paths). It uses SwiftUI for the UI, SwiftData backed by CloudKit for persistence and sync, and Apple's Foundation Models framework (Apple Intelligence) for AI features.

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| Cloud sync | CloudKit (`iCloud.com.adamdrew.takenote`) |
| AI / LLM | Apple FoundationModels (`SystemLanguageModel`) |
| Full-text search | SQLite FTS5 via SQLite.swift |
| Vector search | NLEmbedding (NaturalLanguage framework), in-memory |
| Markdown editor | CodeEditorView (SPM) |
| Markdown renderer | MarkdownUI (SPM) |
| Widgets | WidgetKit |
| System integration | AppIntents (Siri/Shortcuts), ControlWidget |

## Target Platforms

- macOS 26 and later
- iOS 26 and later
- AI features require Apple Intelligence to be enabled on the device

Conditional compilation uses `#if os(macOS)`, `#if os(iOS)`, and `#if DEBUG` throughout the codebase.

## App Targets

The Xcode project contains three targets:

| Target | Purpose |
|---|---|
| `TakeNote` | Main app |
| `NewNoteControl` | WidgetKit extension (Inbox widget, Starred widget, New Note control widget) |
| `TakeNoteShare` | Defined in project but contains no Swift source files at time of survey |

## Component Map

```
TakeNoteApp (entry point)
├── ModelContainer (SwiftData, CloudKit-backed)
│   └── Models: Note, NoteContainer, NoteLink
├── TakeNoteVM (@Observable, @MainActor)
│   └── Shared via SwiftUI Environment
├── SearchIndexService (@Observable, @MainActor)
│   └── SearchIndex (FTS5 / SQLite)
├── AppBootstrapper
│   ├── makeModelConfiguration()
│   ├── bootstrapDevSchemaIfNeeded() [DEBUG only]
│   └── installReconciler()
│       └── SystemFolderReconciler
├── SnapshotController
│   └── Writes snapshot.json to App Group container
└── Windows
    ├── main-window → MainWindow
    │   ├── Sidebar (folder list, tag list)
    │   ├── NoteList
    │   └── NoteEditor / MultiNoteViewer
    ├── note-editor-window → NoteEditorWindow (detached editor)
    └── chat-window → ChatWindow (AI chat, feature-flagged)
```

## Data Flow

1. **User creates a note**: `TakeNoteVM.addNote()` inserts into `ModelContext`, saves; SwiftData syncs to CloudKit.
2. **Note edited**: `NoteEditor` writes to `Note.content` directly; on note deselection `NoteList` triggers `generateSummary()`, `reindex()`, and `NoteLinkManager.generateLinksFor()`.
3. **CloudKit sync arrives**: `NSPersistentStoreRemoteChange` notification triggers `SystemFolderReconciler.runOnce()` and a full `SearchIndexService.reindexAll()`. The reconciler also runs on every local save because `installReconciler` is called with `listenForLocalSaves: true` in `TakeNoteApp.init()`.
4. **Widgets**: `SnapshotController.takeSnapshot()` writes a JSON snapshot to the shared App Group on app foreground, background, and every 10 minutes while active. Widgets read the snapshot via `ContainerProvider`.
5. **AI Chat**: `ChatWindow` calls `SearchIndex.searchNatural()` to retrieve relevant note chunks (RAG), assembles a prompt with excerpts and chat history, and calls `LanguageModelSession.respond()`.

## URL Scheme

`takenote://note/<UUID>` — deep link to open a specific note by UUID. Handled by `onOpenURL` in `MainWindow`, routed through `TakeNoteVM.loadNoteFromURL()`.

## App Group

App group identifier: `group.TakeNote`

Used to share `snapshot.json` between the main app and widget extensions.

## Feature Flag

**Magic Chat** is gated by an Info.plist boolean key `MagicChatEnabled`. The flag is read by `chatFeatureFlagEnabled` (a global computed variable in `ChatFeatureFlagEnabled.swift`). When false, the Chat window UI and search indexing are disabled.

## CloudKit Schema Management

TakeNote has over 1000 real users with data in CloudKit. Schema management is safety-critical.

### Schema Change Protocol

When SwiftData model schema changes (adding, removing, or renaming a persisted field or relationship on `Note`, `NoteContainer`, or `NoteLink`), the developer must:

1. Bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` (inside `#if DEBUG`).
2. Run a DEBUG build. `AppBootstrapper.bootstrapDevSchemaIfNeeded()` detects the version bump and pushes the new schema to the CloudKit **development** environment.
3. Manually promote the schema from development to **production** via the [Apple CloudKit Dashboard](https://icloud.developer.apple.com/).
4. Only after step 3 can the app be shipped to users.

Comments marked `// Hey! // Hey you!` in model files serve as reminders. The model files also say "And don't forget to promote to prod!!!"

Changes to `@Transient` properties (e.g., `aiSummaryIsGenerating`) do not require a version bump because they are not persisted.

### Why `ckBootstrapVersionCurrent` Is `#if DEBUG` Only

`ckBootstrapVersionCurrent` and `ckBootstrapVersionKey` are intentionally inside `#if DEBUG`. This is correct, not a mistake. The reasoning:

- Schema bootstrapping uses `NSPersistentCloudKitContainer.initializeCloudKitSchema()`, which pushes the current SwiftData schema to CloudKit's **development** environment. This is a developer action, not a user action.
- Production builds never need this code path. By the time a release build reaches users, the schema has already been promoted to the production CloudKit container via the Dashboard.
- The bootstrap function creates a **temporary** SQLite file (random UUID filename in the system temp directory) for the `NSPersistentCloudKitContainer`. It does **not** touch the app's actual SwiftData store.

### Bootstrap Mechanics (DEBUG only)

In `TakeNoteApp.init()`:

1. `TakeNoteApp.debugStoreURL()` computes the DEBUG store path at `~/Library/Application Support/TakeNoteDev/TakeNote.sqlite`.
2. A temp bootstrap URL is created: `FileManager.default.temporaryDirectory/CKBootstrap-<UUID>.sqlite`.
3. `AppBootstrapper.bootstrapDevSchemaIfNeeded()` is called with the temp URL and `ckBootstrapVersionCurrent`.
4. Inside the bootstrap function: if the stored version in `UserDefaults` is less than `ckBootstrapVersionCurrent`, a temporary `NSPersistentCloudKitContainer` is created with the temp store, `initializeCloudKitSchema()` is called, the temp store is detached, and the version is saved to `UserDefaults`.
5. Expected network errors (`CKError.networkUnavailable`, `.notAuthenticated`, etc.) and Cocoa-domain errors are logged at `.info` level and swallowed. Unexpected errors are logged at `.warning` level. Neither causes a crash.
