# AI Features

## Overview

TakeNote has three AI features, all powered by Apple's `FoundationModels` framework via `SystemLanguageModel.default`. All features require Apple Intelligence to be enabled on the device. AI availability is checked via `languageModel.availability == .available` (exposed as `TakeNoteVM.aiIsAvailable`).

---

## Feature Flag: Magic Chat

Magic Chat (the AI chat window) is separately gated by an Info.plist boolean:

```swift
// ChatFeatureFlagEnabled.swift
var chatFeatureFlagEnabled: Bool {
    return Bundle.main.object(forInfoDictionaryKey: "MagicChatEnabled") as? Bool ?? false
}
```

When `false`: the Chat window never opens and the Chat toolbar button is hidden. FTS search indexing continues to run unconditionally (see L07) — the feature flag gates only the Chat UI surfaces, not the search index.

---

## Magic Format

**Files:** `TakeNote/Library/MagicFormatter.swift`, `TakeNote/Prompts/MagicFormatPrompt.swift`

Converts the full content of the open note from plain text to well-structured Markdown.

### MagicFormatter

`@MainActor`, `@Observable`. Follows the project-standard `@Observable` pattern.

| Property | Type | Description |
|---|---|---|
| `isAvailable` | `Bool` | Computed: `languageModel.isAvailable` (a property on `SystemLanguageModel`). Note this is a different check path than `TakeNoteVM.aiIsAvailable`, which uses `languageModel.availability == .available`. Both check the same underlying availability but via different API surfaces. |
| `formatterIsBusy` | `Bool` | `true` while a session is in progress; drives the progress sheet in NoteEditor. |
| `sessionCancelled` | `Bool` | Fake-cancel flag (LanguageModelSession cannot be truly cancelled). |

**Methods:**

- `magicFormat(_ text: String) async -> MagicFormatterResult` — the core method. Creates a fresh `LanguageModelSession` per call (reusing would accumulate context and cause context window errors). Hashes input, calls `session.respond(to:)`, checks for the failure token `TAKENOTE_MAGICFORMAT_FORMATFAILED`, strips any Markdown fence wrapper via `unwrapMarkdownFence()`.
- `cancel()` — sets `sessionCancelled = true` and clears `formatterIsBusy`. The cancelled flag is checked after the session resolves; the view silently discards the result via `result.wasCancelled`.
- `hashFor(_ input: String) -> String` — SHA-256 hex of input. Used to detect content drift between when formatting started and when it finished.

### MagicFormatterResult

```swift
struct MagicFormatterResult {
    let inputHash: String      // SHA-256 of input at time of call
    let formattedText: String  // Result or error message
    let didSucceed: Bool
    let wasCancelled: Bool
    let error: Error?
}
```

### Failure Handling

The prompt instructs the model to output `TAKENOTE_MAGICFORMAT_FORMATFAILED` (the `MAGIC_FORMAT_FAILURE_TOKEN` constant) if it cannot improve the formatting. `MagicFormatter` detects this token and sets `didSucceed = false`.

### Prompt

The `MAGIC_FORMAT_PROMPT` instructs the model to:
- Output only formatted Markdown, no commentary or wrapping fences.
- Infer headings, lists, code blocks, emphasis, task items, and links from content.
- Preserve meaning exactly.
- Output the failure token if the document is already well-formatted or cannot be improved.

---

## Magic Assistant

**Files:** `TakeNote/Views/NoteEditor/NoteEditor.swift` (invocation), `TakeNote/Prompts/MagicAssistantPrompt.swift`

Performs Markdown transformations on the currently selected text in the note editor. Presented as a `ChatWindow` popover inside `NoteEditor`.

### Invocation

When text is selected in edit mode, a Magic Assistant toolbar button appears. Tapping it opens a `ChatWindow` configured as:

```swift
ChatWindow(
    context: selectedText,
    instructions: MAGIC_ASSISTANT_PROMPT,
    prompt: "Perform the instructions in the {{USER_REQUEST}} based on the {{CONTEXT}}:\n\nUSER_REQUEST:\n",
    searchEnabled: false,
    onBotMessageClick: assistantSelectionReplacement,
    toolbarVisible: false,
    useHistory: false
)
```

`onBotMessageClick` replaces the selection in the note with the bot's response text.

### Prompt

`MAGIC_ASSISTANT_PROMPT` instructs the model to:
- Accept a user request and a context (selected text).
- Output only a Markdown transformation of the selected text — no new content, no explanations.
- Refuse with `"I don't know how to do that."` only if the text is empty, the request adds new content, or it is inherently non-Markdown.
- Use a fallback chain (tabular → list → nice Markdown) before refusing.

---

## Magic Chat

**Files:** `TakeNote/Views/ChatWindow/ChatWindow.swift`, `TakeNote/Views/ChatWindow/MessageBubble.swift`, `TakeNote/Prompts/MagicChatPrompt.swift`

A RAG-based Q&A chatbot over the user's notes.

### Retrieval (RAG)

On each user query, `SearchIndex.searchNatural()` retrieves up to 5 relevant note chunks. The retrieved `[SearchHit]` values are captured into a `capturedSources` local constant at ask-time (before any async gap) and passed into `generateResponse(sources:)`, where they are stored on the bot `ConversationEntry` via `entry.sources`. These chunks are also injected into the LLM prompt as `SOURCE EXCERPTS`.

### Prompt Assembly

```
[MAGIC_CHAT_PROMPT as system instructions]
Provide an answer to the following question:

<user query>

SOURCE EXCERPTS:

SOURCE EXCERPT 0:
<chunk text>

...

CHAT HISTORY:

User: <prior message>
Assistant: <prior response>
...
```

### System Instructions (MAGIC_CHAT_PROMPT)

Instructs the model to:
- Answer only from `SOURCE EXCERPTS`, not world knowledge.
- Use `CHAT HISTORY` only for context resolution (pronouns, follow-ups).
- Be concise; use bullets only for lists.
- Respond with `"I couldn't find that in your notes."` if no relevant content is found.

### Data Types

| Type | Description |
|---|---|
| `SearchHit` | `struct SearchHit: Identifiable, Hashable` — FTS result with `id: Int64`, `noteID: UUID`, `chunk: String`. Conforms to `Hashable` to allow use as `Set` element and in `[SearchHit]` stored on `ConversationEntry`. |
| `ConversationEntry` | `struct ConversationEntry: Identifiable, Hashable` — one message in the conversation. Fields: `id: UUID`, `sender: Sender`, `text: String`, `sources: [SearchHit] = []`, `isComplete: Bool = false`. |
| `Sender` | `enum Sender` — `.human` or `.bot`. |

### Session Lifecycle and Streaming

A new `LanguageModelSession` is created inside `generateResponse(sources:)` per invocation. No session is reused across turns.

The bot `ConversationEntry` is appended to the conversation with `text: ""` and `sources: sources` **before** the streaming loop begins, so SwiftUI can render the bubble immediately. `generateResponse(sources:)` then calls `session.streamResponse(to:)` to obtain a `ResponseStream` (`AsyncSequence`). Each element of the stream is a cumulative partial string (not a delta); it is assigned directly to `conversation[botIndex].text` — not appended. After the loop finishes, `unwrapMarkdownFence` is applied to the final text and `conversation[botIndex].isComplete` is set to `true`. On error, the text is set to `"Something went wrong. Sorry."` and `isComplete` is set to `true`. In all paths, `responseIsGenerating` is reset to `false` after the `do/catch` block.

### Input Locking

The `TextField` container `HStack` has `.disabled(responseIsGenerating)` applied. The input is visually and functionally disabled for the full duration of streaming. The `askQuestion()` guard `guard !trimmed.isEmpty, !responseIsGenerating else { return }` remains as defense in depth.

### Loading Indicator (Animated Dots)

While a bot `ConversationEntry` has `text == ""` and `isComplete == false` (i.e., waiting for the first streaming token), `MessageBubble` renders a three-dot animated typing indicator **inside** the bot glass-effect bubble — the same styled container used for all bot messages. The dots disappear automatically when `entry.text` becomes non-empty (first token arrives and mutates the entry's text in-place), which causes `MessageBubble` to switch to the text rendering branch.

The indicator is implemented as a private `TypingIndicator` struct inside `MessageBubble.swift`. It uses `PhaseAnimator` with phases `[0, 1, 2]` to produce a continuously cycling sequential wave: in each phase, the corresponding dot (index 0, 1, or 2) renders at 1.4× scale while the others stay at 1.0×. The animation loops indefinitely while the view is on screen. `TypingIndicator` reads `@Environment(\.accessibilityReduceMotion)` directly: when `reduceMotion` is `true`, all three dots render at uniform scale with no `PhaseAnimator` applied. Animation state and the `reduceMotion` environment property live entirely in `MessageBubble.swift` — `ChatWindow` holds neither.

### AI Availability Gate

`ChatWindow.generateResponse(sources:)` checks `SystemLanguageModel.default.availability == .available` before creating a `LanguageModelSession`. If Apple Intelligence is unavailable, a bot message reading "Apple Intelligence is not available on this device." is appended (with `isComplete: true`), `responseIsGenerating` is reset to `false`, and the function returns early. No `LanguageModelSession` is instantiated on the unavailable code path. This check is performed directly on `SystemLanguageModel.default` rather than through `TakeNoteVM.aiIsAvailable` because `ChatWindow` is also used as the Magic Assistant popover inside `NoteEditor`, where it may not have access to `TakeNoteVM`.

### Citation Links

After streaming completes (`entry.isComplete == true`), `MessageBubble` renders citation links below the bot bubble — one `Link` per unique source note. Sources are deduplicated by `noteID` via the `deduplicated(_:)` helper (using a `Set<UUID>`). Links use `Color.takeNotePink`, font `.caption`, and open via `takenote://note/<UUID>` deep links. No citation row renders when: `isHuman` is `true`, `entry.isComplete` is `false`, `entry.sources` is empty, or all sources deduplicate to nothing.

`MessageBubble` accepts `notes: [Note] = []` to look up note titles. `ChatWindow` passes `allNotes` (from `@Query() var allNotes: [Note]`) to each `MessageBubble` call. When `searchEnabled` is `false` (Magic Assistant mode), `capturedSources` is always empty (`[]`), so no citations render.

### `ChatWindow` Properties Added (Phase 0013)

| Property | Type | Description |
|---|---|---|
| `allNotes` | `@Query() [Note]` | All notes from SwiftData, used for citation title lookup. |

Note: `reduceMotion` and `dotPhase` were added in Phase 0013 but removed in Phase 0014. The typing indicator and its animation state moved to `MessageBubble` (see below).

### `MessageBubble` Changes (Phase 0013)

| Addition | Description |
|---|---|
| `notes: [Note] = []` | Notes passed in from `ChatWindow.allNotes` for citation title lookup. |
| `noteTitle(for:)` | Private helper that finds a note by UUID and returns its title. |
| `deduplicated(_:)` | Private helper that filters `[SearchHit]` to unique `noteID` values. |
| Citation links block | Renders in `VStack` after the Accept button row, gated on `!isHuman && entry.isComplete && !entry.sources.isEmpty`. |

### `MessageBubble` Changes (Phase 0014)

| Addition | Description |
|---|---|
| `TypingIndicator` (private struct) | A `PhaseAnimator`-based three-dot typing indicator defined in `MessageBubble.swift`. Reads `@Environment(\.accessibilityReduceMotion)` and shows static dots when reduce motion is enabled. Cycles through phases `[0, 1, 2]`, highlighting one dot at 1.4× scale per phase. |
| `bubble` branching logic | The `bubble` computed property now branches on `!isHuman && entry.text.isEmpty && !entry.isComplete` to render `TypingIndicator` inside the glass-effect bubble styling, rather than `Text(entry.text)`. When `entry.text` becomes non-empty, SwiftUI switches to the text rendering branch and `TypingIndicator` is torn down, stopping the animation. |

### iOS Overlay Polish (Phase 0015)

All changes in this section were originally iOS-only. macOS empty-state behavior was widened in Phase 0016 (see below).

#### Dismiss on Citation Link Tap

When the user taps a `takenote://note/<UUID>` citation link inside the iOS chat overlay, the overlay dismisses so the navigated note becomes visible.

Implementation: `ChatWindow` declares `@Environment(\.dismiss) private var dismiss` inside an `#if os(iOS)` block. An `.onOpenURL { _ in dismiss() }` modifier is applied to the view inside `#if os(iOS)`. SwiftUI URL propagation allows both this handler (which dismisses the sheet) and `MainWindow`'s `onOpenURL` handler (which performs the actual note navigation) to fire in sequence. No explicit `UIApplication.shared.open(_:)` forwarding is needed.

#### Empty-State Placeholder

When `conversation` is empty, a centered gray placeholder is shown in place of the empty scroll area.

- Implemented as `var EmptyStatePlaceholder: some View` (`UpperCamelCase` sub-view convention) in a shared `// MARK: - Sub-Views` section of `ChatWindow` (not platform-guarded).
- Contains a `VStack` with two `Spacer()` views for vertical centering plus a `Text("MagicChat")` (`.title2`, bold) and a descriptive subtitle `Text`, both using `.foregroundStyle(.secondary)`.
- Applied via `.overlay { if conversation.isEmpty { EmptyStatePlaceholder } }` on the `ScrollView`. SwiftUI reactivity causes the placeholder to disappear automatically once `conversation` is non-empty (first message sent).
- **Cross-platform as of Phase 0016.** Originally iOS-only (Phase 0015); the `#if os(iOS)` guard was removed in Phase 0016 so the placeholder renders on macOS as well (inside the standalone Chat Window).

#### iOS Title Bar

The iOS chat overlay has a custom title bar with a centered "MagicChat" label and a New Chat button on the right.

- Implemented as `var TitleBar: some View` (`UpperCamelCase` sub-view convention) inside `#if os(iOS)` on `ChatWindow`.
- Uses a `ZStack`: the "MagicChat" `Text` is in the center layer; an `HStack { Spacer(); Button }` pins the New Chat button to the trailing edge.
- A `Divider()` is placed below the `ZStack` inside a wrapping `VStack`.
- `TitleBar` is rendered at the top of the `VStack` in `body`, inside `#if os(iOS)`, and only when `toolbarVisible == true`. When `toolbarVisible == false` (Magic Assistant mode), no title bar appears.
- The New Chat button calls the existing `newChat()` method.

#### Animated Title Color During Generation

While `responseIsGenerating == true`, the "MagicChat" title text in `TitleBar` cycles through a four-color sequence: pink → orange → purple → blue. When idle, it is static `Color.takeNotePink`.

- A file-scope constant `private let titleColors: [Color] = [.takeNotePink, .orange, .purple, .blue]` is defined inside `#if os(iOS)`.
- `@State private var titleColorPhase: Int = 0` tracks the current position in the cycle.
- `@Environment(\.accessibilityReduceMotion) private var reduceMotion` is read to suppress animation when the user has enabled Reduce Motion.
- A `.task(id: responseIsGenerating)` modifier drives the cycling loop: when `responseIsGenerating` becomes `true` and `reduceMotion` is `false`, an `async while` loop sleeps 500ms then increments `titleColorPhase = (titleColorPhase + 1) % titleColors.count`. When `responseIsGenerating` becomes `false` or `reduceMotion` is `true`, the task resets `titleColorPhase = 0` and returns.
- The title `Text` in `TitleBar` uses `responseIsGenerating && !reduceMotion ? titleColors[titleColorPhase] : Color.takeNotePink` as its foreground style, with `.animation(.easeInOut(duration: 0.4), value: titleColorPhase)` applied.
- All animation state and the task are inside `#if os(iOS)` blocks; macOS and visionOS are unaffected.

#### iOS Toolbar New Chat Button Removed

The toolbar `ToolbarItem` containing the New Chat button is now wrapped in `#if os(macOS)` and `#if os(visionOS)` blocks so it no longer renders on iOS (where the equivalent button lives in `TitleBar`). macOS and visionOS toolbar buttons are preserved exactly as before.

### iOS Sidebar Toolbar Additions (Phase 0016)

Two new toolbar buttons were added to the sidebar column toolbar in `MainWindow.swift`, inside an `#if os(iOS)` block, so they appear on the root sidebar view (visible from app launch before any note container is selected).

#### Search Button (Phase 0016 — non-functional; replaced in Phase 0017)

Phase 0016 added a `DefaultToolbarItem(kind: .search, placement: .bottomBar)` to the sidebar column toolbar. This item did not work: `DefaultToolbarItem(kind: .search)` requires a `.searchable()` modifier in the same navigation column to wire to, but `.searchable()` was only attached to the `List` in `NoteList` (the content column). No search bar appeared in the sidebar as a result.

**Phase 0017 fix:** The broken `DefaultToolbarItem(kind: .search)` was removed from the sidebar toolbar. Instead, `.searchable(text: $takeNoteVM.noteSearchText)` is attached to the `NavigationSplitView` itself on iOS (inside `#if os(iOS)` in `MainWindow.swift`), following the Apple Notes pattern. This causes the system to render the search bar at the bottom of the sidebar column on iPhone when the sidebar is visible. `noteSearchText` was moved from a local `@State` on `NoteList` to `TakeNoteVM.noteSearchText` (L09 — TakeNoteVM as sole state manager) so a single binding can serve both the NavigationSplitView-level searchable on iOS and the List-level searchable on macOS. When search text is non-empty, results are global (all non-trash/non-buffer notes) regardless of selected folder.

#### Magic Chat Button

A `ToolbarItem(placement: toolbarPlacement)` containing a chat button is added to the sidebar toolbar, gated on `chatFeatureFlagEnabled && chatEnabled` (same guard as the existing note-list chat button). The button:

- Calls `doShowSidebarChatPopover()`, which toggles `@State var showSidebarChatPopover: Bool = false`.
- Uses `Label("Chat", systemImage: "message")` and `.help("AI Chat")`, matching the note-list button.
- Attaches a `ChatWindow()` popover via `.popover(isPresented: $showSidebarChatPopover, arrowEdge: .trailing)`.

`showSidebarChatPopover` is independent of `showChatPopover` (used by the note-list chat button), so both popovers are independently dismissible. `doShowSidebarChatPopover()` is a dedicated action method alongside `doShowChatPopover()`.

The `ChatWindow()` on the sidebar uses all default arguments — it queries the full note corpus with FTS search enabled, just like the note-list chat button.

---

## AI Summary

**File:** `TakeNote/Models/Note.swift`

Each `Note` can generate an AI summary via `generateSummary() async`. This is called from three places:
- `NoteList.onChange(of: takeNoteVM.selectedNotes)` — when switching away from a note (if content changed).
- `NoteEditor.togglePreview()` — when toggling from edit to preview mode.
- `NoteListEntry` context menu — the "Regenerate Summary" item.

The summary is a single-sentence summary generated by a `LanguageModelSession`. The result is stored in `note.aiSummary` and displayed in `NoteListEntry`'s `SummaryRow`.

Summary generation is guarded by `canGenerateAISummary()`, which checks four conditions:
1. Content is not empty (`!isEmpty`).
2. Content hash differs from stored hash (`contentHasChanged()`).
3. Generation is not already in progress (`!aiSummaryIsGenerating`).
4. AI is available — checked via `SystemLanguageModel.default.availability != .available` directly on the model object, **not** through `TakeNoteVM.aiIsAvailable`. This is because `generateSummary()` is a method on the `Note` model, which has no access to `TakeNoteVM`.

---

## Shared Utility: unwrapMarkdownFence

**File:** `TakeNote/Library/UnwrapMarkdownFence.swift`

LLM responses sometimes arrive wrapped in triple-backtick Markdown code fences despite prompt instructions. `unwrapMarkdownFence(_ input: String) -> String` strips the opening fence line and closing `` ``` `` if present; otherwise returns the input unchanged. Used by both `MagicFormatter` and `ChatWindow`.
