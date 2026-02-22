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
3. **CloudKit sync arrives**: `NSPersistentStoreRemoteChange` notification triggers `SystemFolderReconciler.runOnce()` and a full `SearchIndexService.reindexAll()`.
4. **Widgets**: `SnapshotController.takeSnapshot()` writes a JSON snapshot to the shared App Group on app foreground, background, and every 10 minutes while active. Widgets read the snapshot via `ContainerProvider`.
5. **AI Chat**: `ChatWindow` calls `SearchIndex.searchNatural()` to retrieve relevant note chunks (RAG), assembles a prompt with excerpts and chat history, and calls `LanguageModelSession.respond()`.

## URL Scheme

`takenote://note/<UUID>` — deep link to open a specific note by UUID. Handled by `onOpenURL` in `MainWindow`, routed through `TakeNoteVM.loadNoteFromURL()`.

## App Group

App group identifier: `group.TakeNote`

Used to share `snapshot.json` between the main app and widget extensions.

## Feature Flag

**Magic Chat** is gated by an Info.plist boolean key `MagicChatEnabled`. The flag is read by `chatFeatureFlagEnabled` (a global computed variable in `ChatFeatureFlagEnabled.swift`). When false, the Chat window UI and search indexing are disabled.

## Schema Change Protocol

When SwiftData model schema changes, developers must:
1. Bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift`.
2. Promote the schema change to production CloudKit.

Comments marked `// Hey! // Hey you!` in model files serve as reminders.
