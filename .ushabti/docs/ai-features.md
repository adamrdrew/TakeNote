# AI Features

## Overview

TakeNote integrates Apple Foundation Models (FoundationModels framework) to provide AI-powered features. These features require macOS/iOS 26+ and Apple Intelligence to be enabled on the device.

## Availability Check

All AI features gate on model availability:

```swift
let languageModel = SystemLanguageModel.default

var aiIsAvailable: Bool {
    return languageModel.availability == .available
}
```

A global feature flag `chatFeatureFlagEnabled` (defined in `ChatFeatureFlagEnabled.swift`) can disable AI chat features entirely.

## AI Features Overview

| Feature | Location | Purpose |
|---------|----------|---------|
| AI Summaries | `Note.swift` | Auto-generated one-line summaries |
| Magic Format | `MagicFormatter.swift` | Converts plain text to formatted Markdown |
| Magic Assistant | `NoteEditor.swift` + `ChatWindow.swift` | Context-aware Markdown transformations |
| AI Chat | `ChatWindow.swift` | RAG-powered Q&A over notes |

## AI Summaries

**Location:** `/TakeNote/Models/Note.swift`

Each note can generate an AI summary of its content.

### Implementation

```swift
func canGenerateAISummary() -> Bool {
    // Checks: not empty, content changed, not generating, model available
}

func generateSummary() async {
    let instructions = """
        Write a single-line summary of the passage. State the core point directly.
        Do not mention the passage or the act of summarizing. No prefaces, labels,
        citations, or quotes. Preserve key entities and facts. Output exactly one
        sentence with no line breaks.
        """
    let session = LanguageModelSession(instructions: instructions)
    let response = try? await session.respond(to: content)
    aiSummary = response?.content ?? ""
}
```

### Change Detection

Uses MD5 hash to detect content changes:

```swift
var contentHash: String  // Stored hash
func generateContentHash() -> String  // Current hash
func contentHasChanged() -> Bool      // Comparison
```

Summaries regenerate only when content has actually changed.

## Magic Format

**Location:** `/TakeNote/Library/MagicFormatter.swift`

Transforms unformatted plain text into well-structured Markdown.

### Class: MagicFormatter

```swift
@MainActor
class MagicFormatter: ObservableObject {
    var session: LanguageModelSession
    @Published var formatterIsBusy: Bool = false
    @Published var sessionCancelled: Bool = false

    func magicFormat(_ text: String) async -> MagicFormatterResult
    func cancel()
}
```

### Result Type

```swift
struct MagicFormatterResult {
    let inputHash: String       // SHA256 of input for validation
    let formattedText: String   // Formatted output or error message
    let didSucceed: Bool
    let wasCancelled: Bool
    let error: Error?
}
```

### Cancellation

Since `LanguageModelSession` cannot be cancelled mid-response, cancellation is simulated:
1. Set `sessionCancelled = true`
2. When response arrives, check flag and throw error
3. Return result with `wasCancelled = true`

### Prompt

Defined in `/TakeNote/Prompts/MagicFormatPrompt.swift`:

- Formats plain text as Markdown
- Infers headings, lists, code blocks, tables
- Never wraps output in code fences
- Returns `TAKENOTE_MAGICFORMAT_FORMATFAILED` token on failure

### UI Integration

The NoteEditor shows a sheet while formatting and validates input hash matches current content before applying changes.

## Magic Assistant

**Location:** UI in `/TakeNote/Views/NoteEditor/NoteEditor.swift`, prompt in `/TakeNote/Prompts/MagicAssistantPrompt.swift`

Performs Markdown transformations on selected text within a note.

### Trigger

Appears as a toolbar button when text is selected in the editor:

```swift
if textIsSelected {
    Button(action: { isAssistantPopoverPresented.toggle() }) {
        Image(systemName: "apple.intelligence")
    }
    .popover(isPresented: $isAssistantPopoverPresented) {
        ChatWindow(
            context: selectedText,
            instructions: MAGIC_ASSISTANT_PROMPT,
            prompt: "Perform the instructions...",
            searchEnabled: false,
            onBotMessageClick: assistantSelectionReplacement,
            toolbarVisible: false,
            useHistory: false
        )
    }
}
```

### Prompt

The Magic Assistant prompt supports:
- Content-preserving transformations (formatting, structuring)
- CSV/TSV to Markdown table conversion
- List normalization and checklist creation
- Code fence wrapping with language detection
- Link formatting

It refuses requests that require inventing content.

### Selection Replacement

When user clicks a bot response, it replaces the selected text:

```swift
func assistantSelectionReplacement(_ replacement: String) {
    guard let note = openNote else { return }
    var s = note.content
    s.replaceSubrange(swiftRange, with: replacement)
    note.setContent(s)
}
```

## AI Chat with RAG

**Location:** `/TakeNote/Views/ChatWindow/ChatWindow.swift`, prompt in `/TakeNote/Prompts/MagicChatPrompt.swift`

A conversational interface that answers questions using notes as context.

### RAG (Retrieval-Augmented Generation)

When a question is asked:
1. Query is sent to `SearchIndexService.searchNatural()`
2. Top matching chunks are retrieved from FTS5 index
3. Chunks are included in the prompt as "SOURCE EXCERPTS"

```swift
private func makePrompt() -> String {
    var llmPrompt = prompt ?? "Provide an answer to the following question:\n\n"
    llmPrompt += "\(conversation.last?.text ?? "")\n\n"

    if context != nil {
        llmPrompt += "CONTEXT: \n\(context ?? "")\n\n"
    }

    if searchEnabled {
        llmPrompt += "SOURCE EXCERPTS:\n\n"
        for (index, result) in searchResults.enumerated() {
            llmPrompt += "SOURCE EXCERPT \(index):\n \(result.chunk)\n\n"
        }
    }

    if useHistory {
        llmPrompt += "CHAT HISTORY:\n\n\(makeConversationString())\n\n"
    }
    return llmPrompt
}
```

### ChatWindow Configuration

The ChatWindow is reusable with different configurations:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `context` | `nil` | Static context (e.g., selected text) |
| `instructions` | `MAGIC_CHAT_PROMPT` | System prompt |
| `prompt` | "Provide an answer..." | User prompt prefix |
| `searchEnabled` | `true` | Enable RAG search |
| `onBotMessageClick` | `nil` | Callback when bot message clicked |
| `toolbarVisible` | `true` | Show toolbar |
| `useHistory` | `true` | Include conversation history |

### Platform Differences

- **macOS:** Opens as separate window via `openWindow(id: TakeNoteVM.chatWindowID)`
- **iOS:** Opens as popover attached to toolbar button

## Utility: unwrapMarkdownFence

**Location:** `/TakeNote/Library/UnwrapMarkdownFence.swift`

LLMs sometimes wrap responses in markdown code fences. This utility strips them:

```swift
func unwrapMarkdownFence(_ text: String) -> String
```

Used by both MagicFormatter and ChatWindow before displaying AI responses.
