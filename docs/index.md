# TakeNote Documentation Index

This documentation provides in-depth coverage of TakeNote's architecture, subsystems, and implementation details.

## Core Architecture

- [Data Models](data-models.md) - SwiftData models: Note, NoteContainer, NoteLink
- [State Management](state-management.md) - TakeNoteVM and the Observable pattern
- [Data Persistence](data-persistence.md) - SwiftData, CloudKit sync, and schema management

## Subsystems

- [Search System](search-system.md) - FTS5 full-text search and vector embeddings
- [AI Features](ai-features.md) - Magic Format, Magic Assistant, summaries, and RAG
- [Link Management](link-management.md) - Bidirectional note linking and backlinks
- [File Import](file-import.md) - Markdown and text file import system

## UI Architecture

- [View Hierarchy](view-hierarchy.md) - SwiftUI structure and navigation
- [Command Pattern](command-pattern.md) - CommandRegistry for menu commands
- [Note Editor](note-editor.md) - CodeEditor integration and markdown editing
- [Platform Differences](platform-differences.md) - macOS vs iOS behavior

## Extensions

- [Widgets](widgets.md) - Home screen, lock screen, and Control Center widgets
- [App Intents](app-intents.md) - Siri shortcuts integration

## Reference

- [Quirks and Edge Cases](quirks.md) - Non-obvious behavior and workarounds
- [URL Scheme](url-scheme.md) - Deep linking format
