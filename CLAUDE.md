# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation

For in-depth documentation on all subsystems, see [docs/index.md](docs/index.md).

**Important:** When making changes to the codebase, keep the documentation in `docs/` updated to reflect those changes.

## Build and Development

This is a native Swift/SwiftUI app for macOS and iOS. Open `TakeNote.xcodeproj` in Xcode to build and run.

**Requirements:** macOS 26 or iOS 26+. AI features require Apple Intelligence support.

**Dead code analysis:**
```bash
periphery scan
```

**Schema changes:** When modifying SwiftData models (`Note`, `NoteContainer`, `NoteLink`), bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` to trigger CloudKit schema updates in DEBUG builds.

## Architecture

**MVVM with Observable pattern:**
- `TakeNoteVM` (`TakeNoteVM.swift`) - Main `@Observable` view model managing app state (selected notes, folders, sort order)
- Views bind to the view model and use SwiftData's `ModelContext` for persistence

**Data layer:**
- SwiftData models in `Models/`: `Note`, `NoteContainer` (folders and tags), `NoteLink` (bidirectional note links)
- CloudKit sync via SwiftData's built-in iCloud integration
- `NoteContainer` serves as both folders and tags (differentiated by `isTag` property)
- System containers: Inbox, Trash, Starred, Buffer (auto-created on first launch)

**AI integration (Apple Foundation Models):**
- `MagicFormatter` - Converts plain text to Markdown using LLM
- `MagicAssistantPrompt` / `MagicChatPrompt` - AI prompt templates in `Prompts/`
- `Note.generateSummary()` - Auto-generates AI summaries using `LanguageModelSession`
- `EmbeddingProvider` / `VectorSearchIndex` / `Chunking` - RAG infrastructure for semantic search

**Library utilities (`Library/`):**
- `SearchIndexService` / `SearchIndex` - Full-text and vector search
- `NoteLinkManager` - Manages bidirectional note linking (backlinks)
- `AppBootstrapper` - CloudKit schema initialization and reconciliation
- `SystemFolderReconciler` - Ensures system folders exist after sync

**Widget extension (`NewNoteControl/`):**
- Separate target for Control Center widgets and home/lock screen widgets
- Shares SwiftData models via app group

## Platform Differences

Uses conditional compilation for platform-specific behavior:
- macOS uses `Window` scene; iOS uses `WindowGroup`
- macOS auto-selects Inbox on launch; iPhone starts on container list
- `#if os(macOS)` and `#if os(iOS)` throughout

## URL Scheme

`takenote://note/{uuid}` - Deep links to specific notes via `TakeNoteVM.loadNoteFromURL()`
