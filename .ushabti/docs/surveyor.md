# Surveyor Working Document

## Observations

### Core Application

- **Type:** system
- **Location:** `/TakeNote/TakeNoteApp.swift`
- **Purpose:** App entry point and scene configuration. Initializes SwiftData container with CloudKit sync, sets up reconciler for system folders, manages scene lifecycle and snapshots.
- **Key files:** `TakeNoteApp.swift`
- **Dependencies:** SwiftData, CloudKit, AppBootstrapper, SystemFolderReconciler, SearchIndexService

### View Model

- **Type:** system
- **Location:** `/TakeNote/TakeNoteVM.swift`
- **Purpose:** Central @Observable view model managing application state: selected notes, folders, tags, sorting preferences, and all CRUD operations for notes and containers.
- **Key files:** `TakeNoteVM.swift`
- **Dependencies:** SwiftData ModelContext, FoundationModels (SystemLanguageModel)

### Data Models

- **Type:** system
- **Location:** `/TakeNote/Models/`
- **Purpose:** SwiftData @Model definitions for persistent storage with CloudKit sync
- **Key files:** `Note.swift`, `NoteContainer.swift`, `NoteLink.swift`
- **Dependencies:** SwiftData, CryptoKit, FoundationModels

### Library Utilities

- **Type:** subsystem
- **Location:** `/TakeNote/Library/`
- **Purpose:** Shared utilities and services including app bootstrap, search indexing, magic formatting, note linking, and file import
- **Key files:** `AppBootstrapper.swift`, `SearchIndex.swift`, `SearchIndexService.swift`, `MagicFormatter.swift`, `NoteLinkManager.swift`, `SystemFolderReconciler.swift`, `SnapshotController.swift`, `Chunking.swift`, `VectorSearchIndex.swift`, `FileImport.swift`
- **Dependencies:** SQLite.swift, NaturalLanguage, CryptoKit, FoundationModels

### AI Prompts

- **Type:** subsystem
- **Location:** `/TakeNote/Prompts/`
- **Purpose:** System prompts for Apple Foundation Models powering AI features
- **Key files:** `MagicAssistantPrompt.swift`, `MagicFormatPrompt.swift`, `MagicChatPrompt.swift`
- **Dependencies:** None (string constants)

### Views - Main Window

- **Type:** subsystem
- **Location:** `/TakeNote/Views/MainWindow/`
- **Purpose:** Primary navigation and layout using NavigationSplitView with sidebar, content (note list), and detail (editor)
- **Key files:** `MainWindow.swift`, `Sidebar.swift`, `NoteSortPopover.swift`, `AddTagButton.swift`, `HistoryPanel.swift`
- **Dependencies:** TakeNoteVM, SwiftData queries

### Views - Note Editor

- **Type:** subsystem
- **Location:** `/TakeNote/Views/NoteEditor/`
- **Purpose:** Markdown editing with live preview, Magic Format integration, Magic Assistant popover, and backlinks display
- **Key files:** `NoteEditor.swift`, `NoteEditorWindow.swift`, `BackLinks.swift`
- **Dependencies:** CodeEditorView, LanguageSupport, MarkdownUI, MagicFormatter, NoteLinkManager

### Views - Note List

- **Type:** subsystem
- **Location:** `/TakeNote/Views/NoteList/`
- **Purpose:** Displays notes in the selected container with search, sorting, and selection
- **Key files:** `NoteList.swift`, `NoteListEntry.swift`, `NoteListHeader.swift`
- **Dependencies:** TakeNoteVM, SwiftData queries

### Views - Folder and Tag Lists

- **Type:** subsystem
- **Location:** `/TakeNote/Views/FolderList/`, `/TakeNote/Views/TagList/`
- **Purpose:** Sidebar components for displaying and managing folders and tags
- **Key files:** `FolderList.swift`, `FolderListEntry.swift`, `TagList.swift`, `TagListEntry.swift`, `NoteContainerDetailsEditor.swift`
- **Dependencies:** TakeNoteVM, SwiftData queries

### Views - Chat Window

- **Type:** subsystem
- **Location:** `/TakeNote/Views/ChatWindow/`
- **Purpose:** AI chat interface with RAG (Retrieval-Augmented Generation) using search index for context
- **Key files:** `ChatWindow.swift`, `MessageBubble.swift`, `ContextBubble.swift`
- **Dependencies:** FoundationModels, SearchIndexService

### Views - Menu Commands

- **Type:** subsystem
- **Location:** `/TakeNote/Views/Commands/`
- **Purpose:** macOS menu bar commands and keyboard shortcuts
- **Key files:** `FileCommands.swift`, `EditCommands.swift`, `ViewCommands.swift`, `WindowCommands.swift`
- **Dependencies:** FocusedValues for scene communication

### Views - Helpers

- **Type:** utility
- **Location:** `/TakeNote/Views/Helpers/`
- **Purpose:** Reusable view components
- **Key files:** `AIMessage.swift`, `MultiNoteViewer.swift`, `NoteLabelBadge.swift`
- **Dependencies:** None significant

### Views - Welcome

- **Type:** utility
- **Location:** `/TakeNote/Views/WelcomeMessage/`
- **Purpose:** Onboarding welcome sheet shown on first launch
- **Key files:** `WelcomeView.swift`, `WelcomeRow.swift`
- **Dependencies:** None significant

### App Intents

- **Type:** subsystem
- **Location:** `/TakeNote/AppIntents/`
- **Purpose:** Siri and Shortcuts integration for creating notes
- **Key files:** `NewNoteIntent.swift`, `NewNoteWithContentIntent.swift`
- **Dependencies:** AppIntents framework, TakeNoteVM, ModelContainer

### Widget Extension (NewNoteControl)

- **Type:** system
- **Location:** `/NewNoteControl/`
- **Purpose:** Home screen widgets and Control Center controls for quick note access
- **Key files:** `TakeNoteBundle.swift`, `NewNoteControl.swift`, `InboxWidget.swift`, `StarredWidget.swift`, `NoteContainerWidgetView.swift`, `ContainerProvider.swift`
- **Dependencies:** WidgetKit, SwiftData, AppIntents

### Share Extension (TakeNoteShare)

- **Type:** system
- **Location:** `/TakeNoteShare/`
- **Purpose:** Share sheet extension (appears to be minimal/placeholder)
- **Key files:** `Base.lproj/` (storyboard only, no Swift files observed)
- **Dependencies:** Unknown

## Plan

### Step 1: Architecture Overview

- **Status:** complete
- **Target doc:** architecture.md
- **Covers:** High-level architecture, target platforms, technology stack, project structure
- **Notes:** Foundation document for understanding the system

### Step 2: Data Models

- **Status:** complete
- **Target doc:** data-models.md
- **Covers:** Note, NoteContainer, NoteLink SwiftData models, relationships, CloudKit sync
- **Notes:** Core persistence layer

### Step 3: View Model and State Management

- **Status:** complete
- **Target doc:** view-model.md
- **Covers:** TakeNoteVM, state flow, folder/note management methods
- **Notes:** Central state management

### Step 4: AI Features

- **Status:** complete
- **Target doc:** ai-features.md
- **Covers:** Apple Foundation Models integration, MagicFormatter, Magic Assistant, AI summaries, chat with RAG
- **Notes:** Key differentiating feature

### Step 5: Search System

- **Status:** complete
- **Target doc:** search-system.md
- **Covers:** SearchIndex (FTS5), SearchIndexService, chunking, natural language processing
- **Notes:** Powers both search and RAG

### Step 6: Views and Navigation

- **Status:** complete
- **Target doc:** views.md
- **Covers:** MainWindow, NavigationSplitView structure, NoteEditor, NoteList, Sidebar
- **Notes:** UI layer overview

### Step 7: Extensions and Intents

- **Status:** complete
- **Target doc:** extensions.md
- **Covers:** Widget extension, App Intents, Share extension
- **Notes:** System integration points
