# Surveyor Working Document

## Observations

### TakeNote Application (Root)

- **Type:** system
- **Location:** `/TakeNote/`
- **Purpose:** Native macOS and iOS Markdown note-taking app using SwiftUI + SwiftData + CloudKit + Apple Foundation Models (Apple Intelligence)
- **Key files:** `TakeNoteApp.swift`, `TakeNoteVM.swift`
- **Dependencies:** SwiftUI, SwiftData, CloudKit, FoundationModels, CodeEditorView (SPM), MarkdownUI (SPM), SQLite.swift (SPM), NaturalLanguage

---

### Data Models

- **Type:** system
- **Location:** `TakeNote/Models/`
- **Purpose:** SwiftData `@Model` classes representing all persisted entities
- **Key files:** `Note.swift`, `NoteContainer.swift`, `NoteLink.swift`
- **Dependencies:** SwiftData, FoundationModels, WidgetKit

Three persisted model types:
- `Note` — individual note with title, content, dates, starred flag, AI summary, content hash, UUID, folder/tag/starredFolder relationships, and outgoing/incoming NoteLink relationships.
- `NoteContainer` — unified model for folders, tags, and system containers (Inbox, Trash, Starred, Buffer). Discriminated by boolean flags (`isInbox`, `isTrash`, `isTag`, `isStarred`, `isBuffer`).
- `NoteLink` — directed edge between two Notes, tracking `sourceNote` and `destinationNote`.

---

### TakeNoteVM (View Model)

- **Type:** system
- **Location:** `TakeNote/TakeNoteVM.swift`
- **Purpose:** Central `@Observable` `@MainActor` view model shared across the app via SwiftUI environment. Holds UI state, selection, sort preferences, and high-level operations (add/delete notes, folders, tags, move to trash, star toggle, etc.).
- **Key files:** `TakeNoteVM.swift`
- **Dependencies:** SwiftData, FoundationModels

Key state:
- `openNote: Note?` — note open in the editor
- `selectedContainer: NoteContainer?` — currently viewed folder/tag
- `selectedNotes: Set<Note>` — notes selected in the note list
- `inboxFolder`, `trashFolder`, `bufferFolder`, `starredFolder` — references to system containers
- `sortBy: SortBy` / `sortOrder: SortOrder` — persisted in `UserDefaults`

---

### Main Window / Navigation

- **Type:** system
- **Location:** `TakeNote/Views/MainWindow/`
- **Purpose:** Three-column `NavigationSplitView`: Sidebar (folders/tags), NoteList, NoteEditor (or MultiNoteViewer)
- **Key files:** `MainWindow.swift`, `Sidebar.swift`
- **Dependencies:** TakeNoteVM, SwiftData, CommandRegistry

---

### Note Editor

- **Type:** subsystem
- **Location:** `TakeNote/Views/NoteEditor/`
- **Purpose:** Dual-mode editor (raw Markdown via CodeEditorView, or rendered preview via MarkdownUI). Hosts toolbar for toggle preview, Magic Format, Magic Assistant, and backlinks.
- **Key files:** `NoteEditor.swift`, `NoteEditorWindow.swift`, `BackLinks.swift`
- **Dependencies:** CodeEditorView, MarkdownUI, MagicFormatter, NoteLinkManager

---

### Note List

- **Type:** subsystem
- **Location:** `TakeNote/Views/NoteList/`
- **Purpose:** Displays notes for the selected container, with search, sort, star grouping, context menus, drag/drop, and copy/cut/paste support.
- **Key files:** `NoteList.swift`, `NoteListEntry.swift`, `NoteListHeader.swift`
- **Dependencies:** TakeNoteVM, CommandRegistry, SearchIndexService

---

### Sidebar (Folder/Tag Lists)

- **Type:** subsystem
- **Location:** `TakeNote/Views/FolderList/`, `TakeNote/Views/TagList/`, `TakeNote/Views/MainWindow/Sidebar.swift`
- **Purpose:** Renders system folders, user folders, and tags. Handles folder import via drag/drop.
- **Key files:** `Sidebar.swift`, `FolderList.swift`, `FolderListEntry.swift`, `TagList.swift`, `TagListEntry.swift`, `NoteContainerDetailsEditor.swift`
- **Dependencies:** TakeNoteVM, CommandRegistry

---

### CommandRegistry Pattern

- **Type:** abstraction
- **Location:** `TakeNote/Library/CommandRegistry.swift`
- **Purpose:** Maps `PersistentIdentifier` → `() -> Void` closures to allow menubar commands (which live outside the view hierarchy) to invoke operations on specific list items that have focus. Used for Rename, Delete, Star, Copy Markdown Link, Open Editor Window, and Set Color.
- **Key files:** `CommandRegistry.swift`, `Sidebar.swift`, `NoteList.swift`, `EditCommands.swift`
- **Dependencies:** SwiftData, SwiftUI

---

### Menubar Commands

- **Type:** subsystem
- **Location:** `TakeNote/Views/Commands/`
- **Purpose:** Custom SwiftUI Commands for File (New Note, New Folder, New Tag, Empty Trash), Edit (Rename, Delete, Copy Markdown Link, MagicFormat, Magic Assistant, Toggle Star, Set Color), View, and Window menus.
- **Key files:** `FileCommands.swift`, `EditCommands.swift`, `ViewCommands.swift`, `WindowCommands.swift`
- **Dependencies:** CommandRegistry, TakeNoteVM, FocusedValues

---

### AI Features (MagicFormatter, MagicAssistant, ChatWindow)

- **Type:** system
- **Location:** `TakeNote/Library/MagicFormatter.swift`, `TakeNote/Views/ChatWindow/`, `TakeNote/Prompts/`
- **Purpose:** Three AI features powered by Apple's `FoundationModels` (`SystemLanguageModel`):
  1. **Magic Format** — formats a note's content as Markdown using a `LanguageModelSession`.
  2. **Magic Assistant** — performs Markdown transformations on selected text in the editor.
  3. **Magic Chat** — RAG-powered Q&A over the user's notes, gated behind a feature flag (`MagicChatEnabled` in Info.plist).
- **Key files:** `MagicFormatter.swift`, `ChatWindow.swift`, `MagicFormatPrompt.swift`, `MagicAssistantPrompt.swift`, `MagicChatPrompt.swift`, `ChatFeatureFlagEnabled.swift`
- **Dependencies:** FoundationModels, SearchIndexService

---

### Search System (FTS + Vector)

- **Type:** system
- **Location:** `TakeNote/Library/`
- **Purpose:** Full-text search via SQLite FTS5 (`SearchIndex`) and an in-memory dense vector index (`VectorSearchIndex`). `SearchIndexService` is the `@Observable` service layer consumed by the UI. Used by ChatWindow for RAG retrieval.
- **Key files:** `SearchIndex.swift`, `VectorSearchIndex.swift`, `SearchIndexService.swift`, `Chunking.swift`, `EmbeddingProvider.swift`
- **Dependencies:** SQLite.swift, NaturalLanguage

---

### Note Link System

- **Type:** subsystem
- **Location:** `TakeNote/Library/NoteLinkManager.swift`
- **Purpose:** Parses `takenote://note/<UUID>` URLs from note content, creates/deletes `NoteLink` records accordingly, and provides backlink queries for the BackLinks popover in the editor.
- **Key files:** `NoteLinkManager.swift`
- **Dependencies:** SwiftData

---

### SystemFolderReconciler

- **Type:** subsystem
- **Location:** `TakeNote/Library/SystemFolderReconciler.swift`
- **Purpose:** Runs on startup and on CloudKit remote change notifications. Ensures no duplicate system folders exist (CloudKit sync can create duplicates). Merges notes onto a canonical folder and deletes duplicates.
- **Key files:** `SystemFolderReconciler.swift`
- **Dependencies:** SwiftData

---

### AppBootstrapper

- **Type:** utility
- **Location:** `TakeNote/Library/AppBootstrapper.swift`
- **Purpose:** Encapsulates app initialization logic: `ModelConfiguration` setup, DEBUG-only CloudKit Dev schema bootstrap via CoreData, and `SystemFolderReconciler` installation with notification observers.
- **Key files:** `AppBootstrapper.swift`
- **Dependencies:** SwiftData, CloudKit, CoreData

---

### SnapshotController

- **Type:** utility
- **Location:** `TakeNote/Library/SnapshotController.swift`
- **Purpose:** Serializes a lightweight snapshot of all containers and their top 5 most-recently-updated notes to a shared App Group JSON file (`group.TakeNote`). Snapshot is read by widgets and the main app alike. Written on foreground, background, and on a 10-minute timer.
- **Key files:** `SnapshotController.swift`
- **Dependencies:** SwiftData, WidgetKit

---

### Widgets and Control Extension

- **Type:** system
- **Location:** `NewNoteControl/`
- **Purpose:** Provides two WidgetKit widgets (Inbox, Starred) and one ControlWidget (New Note button for Control Center/Lock Screen). All read from `SnapshotController`'s shared JSON.
- **Key files:** `InboxWidget.swift`, `StarredWidget.swift`, `NewNoteControl.swift`, `ContainerProvider.swift`, `NoteContainerWidgetView.swift`
- **Dependencies:** WidgetKit, AppIntents, SnapshotController

---

### AppIntents

- **Type:** subsystem
- **Location:** `TakeNote/AppIntents/`
- **Purpose:** Exposes Siri/Shortcuts integration via `NewNoteIntent` (create empty note) and `NewNoteWithContentIntent` (create note with specified title/content). Both use `AppDependencyManager` to access `ModelContainer` and `TakeNoteVM` at runtime.
- **Key files:** `NewNoteIntent.swift`, `NewNoteWithContentIntent.swift`
- **Dependencies:** AppIntents, SwiftData, TakeNoteVM

---

### File Import

- **Type:** utility
- **Location:** `TakeNote/Library/FileImport.swift`
- **Purpose:** Supports drag-and-drop import of `.md` and `.txt` files (individual) or entire folders (creates a new folder and imports all files within). Called from both `Sidebar` (folder import) and `NoteList` (file import).
- **Key files:** `FileImport.swift`
- **Dependencies:** SwiftData, SearchIndexService

---

### Utility / Library

- **Type:** utility
- **Location:** `TakeNote/Library/`
- **Purpose:** Miscellaneous utilities
- **Key files:**
  - `MarkdownConfiguration.swift` — `LanguageConfiguration` extension for CodeEditorView's Markdown syntax highlighting
  - `UnwrapMarkdownFence.swift` — strips triple-backtick fences from AI-generated Markdown before storing
  - `TextFile.swift` — `FileDocument` adapter for note export as plain text/Markdown
  - `FocusValues.swift` — shared `FocusedValueKey` for `ModelContext`
  - `ChatFeatureFlagEnabled.swift` — reads `MagicChatEnabled` flag from Info.plist

---

## Plan

### Step 1: Architecture Overview

- **Status:** complete
- **Target doc:** `architecture.md`
- **Covers:** overall system, tech stack, target platforms, app extensions, data flow between components
- **Notes:** High-level map of the system; foundation for other docs

### Step 2: Data Models

- **Status:** complete
- **Target doc:** `data-models.md`
- **Covers:** Note, NoteContainer, NoteLink, NoteIDWrapper, all fields and relationships, schema change procedure
- **Notes:** Critical reference for anything touching persistence

### Step 3: View Model and Application State

- **Status:** complete
- **Target doc:** `view-model.md`
- **Covers:** TakeNoteVM, SortBy/SortOrder enums, all state properties, all methods, UserDefaults persistence
- **Notes:** Central state management; all views depend on this

### Step 4: View Layer

- **Status:** complete
- **Target doc:** `views.md`
- **Covers:** MainWindow, Sidebar, NoteList, NoteEditor, ChatWindow, TagList, FolderList, Commands, Helpers, WelcomeView
- **Notes:** UI organization and responsibilities

### Step 5: CommandRegistry Pattern

- **Status:** complete
- **Target doc:** `command-registry.md`
- **Covers:** CommandRegistry class, the FocusedValues bridge, how list items register/unregister commands, how menubar commands invoke them
- **Notes:** Non-obvious architectural pattern that must be understood to change menu or list behavior

### Step 6: AI Features

- **Status:** complete
- **Target doc:** `ai-features.md`
- **Covers:** MagicFormatter, Magic Assistant, Magic Chat (ChatWindow), all three prompts, FoundationModels usage, feature flag, availability check
- **Notes:** All AI work is gated on Apple Intelligence availability

### Step 7: Search System

- **Status:** complete
- **Target doc:** `search-system.md`
- **Covers:** SearchIndex (FTS5/SQLite), VectorSearchIndex (in-memory NLEmbedding), SearchIndexService, Chunking, EmbeddingProvider, SearchHit type
- **Notes:** Used by ChatWindow for RAG retrieval; in DEBUG uses in-memory store

### Step 8: Supporting Systems

- **Status:** complete
- **Target doc:** `supporting-systems.md`
- **Covers:** AppBootstrapper, SystemFolderReconciler, SnapshotController, NoteLinkManager, FileImport, AppIntents, TextFile, utility library files
- **Notes:** Infrastructure and integration layer
