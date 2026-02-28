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
