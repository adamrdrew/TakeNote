# View Layer

## Overview

The UI is structured as a three-column `NavigationSplitView` inside `MainWindow`. All views share `TakeNoteVM` and `SearchIndexService` via the SwiftUI environment.

---

## MainWindow

**File:** `TakeNote/Views/MainWindow/MainWindow.swift`

The root view of the main window scene.

- Renders a `NavigationSplitView` with three columns: Sidebar, NoteList, and detail (NoteEditor or MultiNoteViewer).
- Hosts toolbar items for Add Folder and Add Tag (sidebar column) and Add Note, Sort, AI Chat, and Empty Trash (content column).
- Handles `onOpenURL` for `takenote://` deep links.
- Shows the "notes in buffer" alert on launch and drains Buffer to Inbox.
- Calls `takeNoteVM.folderInit()` on `onAppear`.
- Contains alerts for Empty Trash, Delete Everything (DEBUG), Link Error, and generic errors.
- On macOS uses `Window`; on other platforms uses `WindowGroup`.

**FocusedValues exposed:**
- `\.modelContext` — passes `ModelContext` to menubar commands
- `\.chatEnabled` — whether chat is available
- `\.openChatWindow` — closure to open the chat window
- `\.showDeleteEverything` — closure to trigger debug delete

---

## Sidebar

**File:** `TakeNote/Views/MainWindow/Sidebar.swift`

Left-most column. Contains the full navigation hierarchy.

- Renders three `List` sections: system folders, user folders, tags.
- System folders query: `isTrash || isInbox || isStarred`.
- User folders query: `!isTag && !isTrash && !isInbox && !isBuffer`.
- Tags query: `isTag == true`.
- Accepts folder drag/drop via `folderImport()`.
- Manages three `CommandRegistry` instances for delete, rename, and set-color operations, injecting them into the environment and FocusedValues.

**Environment keys provided to children:**
- `\.containerDeleteRegistry`
- `\.containerRenameRegistry`
- `\.tagSetColorRegistry`

**FocusedValues exposed:**
- `\.containerDeleteRegistry`
- `\.containerRenameRegistry`
- `\.tagSetColorRegistry`
- `\.selectedNoteContainer`

---

## FolderList and FolderListEntry

**Files:** `TakeNote/Views/FolderList/FolderList.swift`, `FolderListEntry.swift`

- `FolderList` — simple ForEach of user folders, sorted by name.
- `FolderListEntry` — single folder row with inline rename field, context menu (rename, delete), and CommandRegistry registration/unregistration on appear/disappear.

---

## TagList and TagListEntry

**Files:** `TakeNote/Views/TagList/TagList.swift`, `TagListEntry.swift`, `NoteContainerDetailsEditor.swift`

- `TagList` — ForEach of tag containers.
- `TagListEntry` — single tag row with colored tag icon, inline rename, context menu (rename, set color, delete), and CommandRegistry registration.
- `NoteContainerDetailsEditor` — color picker popover for editing a tag's color, displayed from context menu or Edit menu.

---

## NoteList

**File:** `TakeNote/Views/NoteList/NoteList.swift`

Middle column. Renders notes for the selected container.

- Filters notes by search text against title and content.
- Sorts by `sortBy`/`sortOrder` from `TakeNoteVM`.
- Groups starred notes in a separate section above non-starred notes.
- Manages five `CommandRegistry` instances: delete, rename, star toggle, copy Markdown link, open editor window.
- On macOS: supports `.copyable`, `.cuttable` (moves note to Buffer folder), and `.pasteDestination` (moves/copies from Buffer or pastes copy).
- Accepts string drop (creates new note from dropped text) and file URL drop (`fileImport`).
- On note deselection (oldValue): triggers `generateSummary()`, `SearchIndexService.reindex()`, and `NoteLinkManager.generateLinksFor()`.

**FocusedValues exposed:** `\.noteDeleteRegistry`, `\.noteRenameRegistry`, `\.noteStarToggleRegistry`, `\.noteCopyMarkdownLinkRegistry`, `\.noteOpenEditorWindowRegistry`, `\.selectedNotes`

### NoteListEntry

**File:** `TakeNote/Views/NoteList/NoteListEntry.swift`

Individual note row. Displays TitleRow (title + star button), MetadataRow (created date + folder/tag badge), and SummaryRow (AI summary or raw content preview).

- Registers five commands in CommandRegistry on `.onAppear`, unregisters on `.onDisappear`.
- Supports swipe actions (trailing: trash + star; leading on iOS: move).
- Supports draggable `NoteIDWrapper` for drag/drop.
- Double-tap opens a detached `NoteEditorWindow`.
- Context menu: Move to Trash, Rename, Go to Note Folder, Open Editor Window, Export, Copy URL, Copy Markdown Link, Regenerate Summary, Remove Tag.
- File export via `.fileExporter` saves note as a `.md` file.

### NoteListHeader

**File:** `TakeNote/Views/NoteList/NoteListHeader.swift`

Displayed as `safeAreaInset` at the top of the NoteList. Shows the selected container's name, icon, and color. Content unknown beyond filename — not read in detail during survey.

---

## NoteEditor

**File:** `TakeNote/Views/NoteEditor/NoteEditor.swift`

Detail column. Dual-mode: preview (rendered Markdown via MarkdownUI) or raw edit mode (CodeEditorView with Markdown syntax highlighting).

- `showPreview: Bool` toggles between modes.
- In preview mode: tapping switches to edit mode; exit command on macOS also switches.
- In edit mode: CodeEditorView renders with a custom `MarkdownConfiguration` language config; a `MarkdownShortcutBar` appears above the keyboard on iOS when no hardware keyboard is connected.
- Toolbar items:
  - Toggle preview (eye icon)
  - Backlinks popover (link icon, shown only if note has incoming links)
  - Magic Format button (wand icon, shown only if AI available)
  - Magic Assistant button (apple.intelligence icon, shown only if text is selected)
- Shows a modal sheet with a cancel button while Magic Format is running.
- On note change: resets to preview mode, re-checks backlink status.

**FocusedValues exposed:** `\.togglePreview`, `\.doMagicFormat`, `\.textIsSelected`, `\.showAssistantPopover`, `\.openNoteHasBacklinks`, `\.showBacklinks`

### BackLinks

**File:** `TakeNote/Views/NoteEditor/BackLinks.swift`

Popover displaying notes that link to the current note. Shown via the link icon toolbar button when `openNoteHasBacklinks` is true. Uses `NoteLinkManager` to fetch source notes.

### NoteEditorWindow

**File:** `TakeNote/Views/NoteEditor/NoteEditorWindow.swift`

A detached window containing a single `NoteEditor`. Opened via double-click on a `NoteListEntry` or the "Open Editor Window" context menu/command. Uses its own `TakeNoteVM` instance (not shared with the main window). The window title is formatted as `"TakeNote / <FolderName> / <NoteTitle>"`.

---

## ChatWindow

**File:** `TakeNote/Views/ChatWindow/ChatWindow.swift`

AI chat interface. Flexible enough to serve two purposes:
1. **Standalone chat window** — full note RAG chat opened from the toolbar (macOS) or toolbar popover (iOS). Gated by `chatFeatureFlagEnabled`.
2. **Magic Assistant inline** — rendered as a popover in `NoteEditor` with a `context` string (selected text), custom `instructions` (Magic Assistant prompt), and an `onBotMessageClick` callback that replaces the selected text.

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `context` | `nil` | Pre-injected context string (selected note text for Magic Assistant). |
| `instructions` | `nil` | LLM system instructions. Defaults to `MAGIC_CHAT_PROMPT`. |
| `prompt` | `nil` | Prompt prefix. Defaults to `"Provide an answer to the following question:\n\n"`. |
| `searchEnabled` | `true` | Whether to run FTS search and include excerpts in the prompt. |
| `onBotMessageClick` | `nil` | Callback receiving bot response text (used by Magic Assistant to replace selected text). |
| `toolbarVisible` | `true` | Whether to show the "New Chat" toolbar button. |
| `useHistory` | `true` | Whether to include chat history in prompts. |

### Data Types

- `Sender` — enum: `.human` / `.bot`
- `ConversationEntry` — `Identifiable, Hashable`. Fields: `id: UUID`, `sender: Sender`, `text: String`.

### Behavior

- On submit: appends user message, runs `SearchIndex.searchNatural()` if `searchEnabled`, assembles prompt with context + excerpts + history, calls `LanguageModelSession.respond()`.
- A new `LanguageModelSession` is created per response (stateless).
- Bot responses are stripped of wrapping Markdown fences via `unwrapMarkdownFence()`.
- "New Chat" button clears `conversation`, `userQuery`, and resets state.

### Supporting Views

- `ContextBubble` — styled bubble displaying the injected `context` string at the top of the conversation.
- `MessageBubble` — individual message bubble. Bot messages are tappable if `onBotMessageClick` is provided.

---

## Commands

**Files:** `TakeNote/Views/Commands/`

SwiftUI `Commands` structs registered in `TakeNoteApp.body`.

### FileCommands

Adds items after `.newItem`: New Note (`⌘N`), New Folder (`⌘F`), New Tag (`⌘T`), Empty Trash (`⌘⌥Delete`). DEBUG: Delete Everything. All read `TakeNoteVM` and `ModelContext` from `FocusedValues`.

### EditCommands

Adds items after `.pasteboard`: Rename (`⌘R`), Copy Markdown Link (`⌘⌥C`), Delete (`⌘Delete`), Set Color (`⌘⌥c`), MagicFormat (`⌘⌥f`), Magic Assistant (`⌘⌥a`), Toggle Star (`⌘S`). Uses `CommandRegistry` instances from `FocusedValues` to dispatch to the correct list item. Disable logic derived from selection and focus state.

### ViewCommands / WindowCommands

Contents not read in detail during survey. Likely standard view/window menu additions.

---

## Helper Views

**Files:** `TakeNote/Views/Helpers/`

- `AIMessage` — styled label for AI-related status messages (e.g., "Magic Format", "Thinking...", "AI Summary Generating...").
- `MultiNoteViewer` — shown in the detail column when multiple notes are selected. Contents not read in detail.
- `NoteLabelBadge` — tag/folder badge displayed on note list entries.

---

## WelcomeView

**Files:** `TakeNote/Views/WelcomeMessage/WelcomeView.swift`, `WelcomeRow.swift`

Onboarding sheet shown on first launch (and when `onboardingVersionCurrent` is bumped). Dismissed by calling the provided callback, which updates `@AppStorage(onboardingVersionKey)`.

---

## Multi-Platform Adaptations

Key platform differences handled throughout:
- macOS uses `Window`; iOS/visionOS use `WindowGroup`.
- Toolbar placements differ: `.secondaryAction` on macOS, `.automatic` on iOS.
- iOS phones start with no selected container (list view); iPads start with Inbox selected.
- Markdown shortcut bar appears on iOS only when soft keyboard is active.
- Copy/cut/paste system is macOS-only.
- AI Chat is a separate window on macOS; a popover on iOS.
