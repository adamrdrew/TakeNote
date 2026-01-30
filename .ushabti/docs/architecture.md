# Architecture Overview

## Overview

TakeNote is a cross-platform Markdown note-taking application built with SwiftUI, targeting macOS 26+ and iOS 26+. The app uses SwiftData for persistence with automatic CloudKit synchronization, and Apple Foundation Models for AI-powered features.

## Target Platforms

- **macOS 26+** - Full desktop experience with multiple windows, menu bar commands
- **iOS 26+** - Adaptive layout for iPhone and iPad
- **visionOS** - Basic support (some conditional compilation observed)

## Technology Stack

| Layer | Technology |
|-------|------------|
| UI Framework | SwiftUI |
| Persistence | SwiftData |
| Cloud Sync | CloudKit (via SwiftData) |
| AI/ML | Apple Foundation Models (FoundationModels framework) |
| Search | SQLite FTS5 (via SQLite.swift) |
| Markdown Editor | CodeEditorView, LanguageSupport |
| Markdown Rendering | MarkdownUI |
| Text Analysis | NaturalLanguage framework |

## Project Structure

```
TakeNote/
├── TakeNote/                    # Main app target
│   ├── TakeNoteApp.swift        # App entry point
│   ├── TakeNoteVM.swift         # Central view model
│   ├── Models/                  # SwiftData models
│   ├── Library/                 # Utilities and services
│   ├── Prompts/                 # AI system prompts
│   ├── Views/                   # SwiftUI views
│   │   ├── MainWindow/
│   │   ├── NoteEditor/
│   │   ├── NoteList/
│   │   ├── FolderList/
│   │   ├── TagList/
│   │   ├── ChatWindow/
│   │   ├── Commands/
│   │   ├── Helpers/
│   │   └── WelcomeMessage/
│   └── AppIntents/              # Siri/Shortcuts integration
├── NewNoteControl/              # Widget extension
│   ├── Controls/
│   ├── Widgets/
│   ├── Views/
│   └── Library/
└── TakeNoteShare/               # Share extension (minimal)
```

## Architecture Pattern

The app follows a **centralized observable view model** pattern:

1. **TakeNoteVM** (`@Observable @MainActor`) holds all application state
2. Views read from and write to the view model
3. SwiftData ModelContext is passed through the environment
4. Changes propagate reactively through SwiftUI's observation system

```
┌─────────────────────────────────────────────────────────────┐
│                        TakeNoteApp                          │
│  - Creates ModelContainer (SwiftData + CloudKit)            │
│  - Instantiates TakeNoteVM                                  │
│  - Sets up SystemFolderReconciler                           │
│  - Configures scene lifecycle                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        TakeNoteVM                           │
│  - openNote: Note?                                          │
│  - selectedContainer: NoteContainer?                        │
│  - selectedNotes: Set<Note>                                 │
│  - inboxFolder, trashFolder, bufferFolder, starredFolder    │
│  - CRUD methods for notes/folders/tags                      │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Sidebar  │   │ NoteList │   │NoteEditor│
        └──────────┘   └──────────┘   └──────────┘
```

## App Initialization Flow

1. **ModelConfiguration** - Debug uses local SQLite, Release uses CloudKit
2. **CloudKit Schema Bootstrap** (DEBUG only) - Pushes schema to CloudKit Dev environment
3. **ModelContainer Creation** - Initializes SwiftData with Note, NoteContainer, NoteLink models
4. **AppDependencyManager** - Registers ModelContainer and TakeNoteVM for AppIntents
5. **SystemFolderReconciler** - Ensures system folders exist and handles CloudKit duplicates
6. **SearchIndexService** - Initializes FTS5 search index

## Scene Configuration

- **Main Window** - `Window` on macOS, `WindowGroup` on iOS
- **Note Editor Window** - Standalone window for editing notes (macOS)
- **Chat Window** - AI chat interface (macOS window, iOS popover)

## Key Design Decisions

### CloudKit Duplicate Handling

The `SystemFolderReconciler` monitors for duplicate system folders (Inbox, Trash, Starred, Buffer) that can occur during CloudKit sync and merges them automatically, preserving notes.

### Search Architecture

Two search systems exist:
1. **FTS5 Full-Text Search** (`SearchIndex`) - SQLite-based text search with BM25 ranking
2. **Vector Search Index** (`VectorSearchIndex`) - Embedding-based semantic search (for future RAG improvements)

### AI Feature Gating

AI features check `SystemLanguageModel.default.availability` and are only available on devices with Apple Intelligence enabled.

### URL Scheme

The app supports `takenote://note/{uuid}` deep links for inter-note linking and external navigation.
