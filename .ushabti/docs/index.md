# Project Documentation

## Project Name

TakeNote

## Description

TakeNote is a native Markdown note-taking app for macOS, iOS/iPadOS, and visionOS. It supports iCloud sync via CloudKit, folder and tag organization, favorites (starred notes), AI-powered summaries, Magic Format (converts plain text to Markdown), and Magic Assistant (targeted Markdown transformations on selected text). An optional AI chat feature enables RAG-based Q&A over the user's notes. The app also provides WidgetKit widgets and a Control Center button for quick note creation. Requires macOS 27, iOS/iPadOS 27, or visionOS 27; AI features require Apple Intelligence.

## Table of Contents

- [Architecture Overview](architecture.md) — Tech stack, app targets, component map, data flow, URL scheme, App Group, and schema change protocol
- [Data Models](data-models.md) — Note, NoteContainer, NoteLink SwiftData models: all fields, relationships, and key methods
- [View Model and Application State](view-model.md) — TakeNoteVM: all state properties, computed properties, and operations
- [View Layer](views.md) — MainWindow, Sidebar, NoteList, NoteEditor, ChatWindow, Commands, and all supporting views
- [CommandRegistry Pattern](command-registry.md) — How menubar commands bridge to list item operations via FocusedValues
- [AI Features](ai-features.md) — Magic Format, Magic Assistant, Magic Chat, AI summaries, prompts, and feature flag
- [Search System](search-system.md) — Core Spotlight, serialized indexing, search delegates, and Magic Chat retrieval
- [Supporting Systems](supporting-systems.md) — AppBootstrapper, SystemFolderReconciler, SnapshotController, NoteLinkManager, FileImport, AppIntents, Widgets, and utility files
