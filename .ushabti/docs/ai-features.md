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

When `false`: the chat window never opens, search indexing is skipped, and the Chat toolbar button is hidden.

---

## Magic Format

**Files:** `TakeNote/Library/MagicFormatter.swift`, `TakeNote/Prompts/MagicFormatPrompt.swift`

Converts the full content of the open note from plain text to well-structured Markdown.

### MagicFormatter

`@MainActor`, `ObservableObject`.

| Property | Type | Description |
|---|---|---|
| `isAvailable` | `Bool` | `languageModel.isAvailable` |
| `formatterIsBusy` | `@Published Bool` | `true` while a session is in progress; drives the progress sheet in NoteEditor. |
| `sessionCancelled` | `@Published Bool` | Fake-cancel flag (LanguageModelSession cannot be truly cancelled). |

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

**Files:** `TakeNote/Views/ChatWindow/ChatWindow.swift`, `TakeNote/Prompts/MagicChatPrompt.swift`

A RAG-based Q&A chatbot over the user's notes.

### Retrieval (RAG)

On each user query, `SearchIndex.searchNatural()` retrieves up to 5 relevant note chunks. These chunks are injected into the LLM prompt as `SOURCE EXCERPTS`.

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

### Session Lifecycle

A new `LanguageModelSession` is created per response. No session is reused across turns — full conversation history is included in each prompt text instead.

---

## AI Summary

**File:** `TakeNote/Models/Note.swift`

Each `Note` can generate an AI summary via `generateSummary() async`. This is called:
- When switching away from a note in `NoteList` (if content changed).
- When toggling from edit to preview mode in `NoteEditor`.
- From the "Regenerate Summary" context menu item.

The summary is a single-sentence summary generated by a `LanguageModelSession`. The result is stored in `note.aiSummary` and displayed in `NoteListEntry`'s `SummaryRow`. Summary generation is guarded by `canGenerateAISummary()`: content must be non-empty, content hash must differ from stored hash, generation must not already be in progress, and AI must be available.

---

## Shared Utility: unwrapMarkdownFence

**File:** `TakeNote/Library/UnwrapMarkdownFence.swift`

LLM responses sometimes arrive wrapped in triple-backtick Markdown code fences despite prompt instructions. `unwrapMarkdownFence(_ input: String) -> String` strips the opening fence line and closing `` ``` `` if present; otherwise returns the input unchanged. Used by both `MagicFormatter` and `ChatWindow`.
