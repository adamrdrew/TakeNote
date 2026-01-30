# Project Documentation

## Project Name

TakeNote

## Description

TakeNote is a powerful Markdown note-taking application for macOS and iOS (macOS 26+, iOS 26+). It features iCloud sync via CloudKit/SwiftData, a folder and tag organization system, favorites, and AI-powered features (summaries, Magic Format, Magic Assistant) using Apple Foundation Models. The app is built with SwiftUI and follows a modern reactive architecture with a central view model.

## Table of Contents

- [Architecture Overview](architecture.md) - High-level architecture, platforms, technology stack, project structure
- [Data Models](data-models.md) - Note, NoteContainer, NoteLink SwiftData models and relationships
- [View Model](view-model.md) - TakeNoteVM state management and CRUD operations
- [AI Features](ai-features.md) - Apple Foundation Models integration, Magic Format, Magic Assistant, AI Chat
- [Search System](search-system.md) - FTS5 full-text search, SearchIndexService, RAG support
- [Views and Navigation](views.md) - MainWindow, NoteEditor, NoteList, Sidebar, and UI components
- [Extensions and Intents](extensions.md) - Widget extension, App Intents, Share extension
