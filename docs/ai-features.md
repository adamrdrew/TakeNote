# AI Features

TakeNote integrates with Apple Foundation Models for AI-powered features. All AI features require Apple Intelligence to be available and enabled.

## Availability Check

```swift
let languageModel = SystemLanguageModel.default

var aiIsAvailable: Bool {
    return languageModel.availability == .available
}
```

## Magic Format

**Files:** `MagicFormatter.swift`, `MagicFormatPrompt.swift`

Converts plain text to well-formatted Markdown.

### Usage Flow

1. User selects text in editor
2. Triggers Magic Format via menu/keyboard
3. MagicFormatter processes text with LLM
4. Result replaces selected text

### State Machine

```swift
@Observable
class MagicFormatter {
    var formatterIsBusy = false
    var sessionCancelled = false
}
```

### Session Management Quirk

A new `LanguageModelSession` is created for each format request:

```swift
// MagicFormatter.swift line 95-98
// Context window issues: Creating new session each time
// because cumulative context causes overflow on repeated reuse
let session = LanguageModelSession(instructions: MAGIC_FORMAT_PROMPT)
```

### Pseudo-Cancellation

Apple's `LanguageModelSession` has no cancel API. Workaround:

```swift
func cancel() {
    sessionCancelled = true
    formatterIsBusy = false
}

// In format():
if sessionCancelled {
    throw MagicFormatterError.cancelled
}
```

Views handle gracefully without showing error UI.

### Hash Verification

Input is hashed before formatting. After response, hash is compared to detect racing changes:

```swift
let inputHash = content.hashValue
// ... wait for response ...
if inputHash != originalHash {
    return MagicFormatterResult(success: false, error: "Content changed during formatting")
}
```

### Failure Token

Prompt instructs LLM to output specific token on failure:
```
TAKENOTE_MAGICFORMAT_FORMATFAILED
```

Response is checked for this token to detect failures.

### Prompt Details

**File:** `MagicFormatPrompt.swift`

Key instructions:
- Do NOT wrap output in markdown code fences
- Output exactly `TAKENOTE_MAGICFORMAT_FORMATFAILED` on failure
- Preserve meaning while improving formatting

## Magic Assistant

Contextual AI help for selected text in the editor.

### Integration

**File:** `NoteEditor.swift` (lines 399-430)

Appears as popover when text is selected:

```swift
if textIsSelected {
    ChatWindow(
        context: selectedText,
        instructions: MAGIC_ASSISTANT_PROMPT,
        searchEnabled: false,
        useHistory: false,
        onBotMessageClick: { replacement in
            replaceSelectedText(with: replacement)
        }
    )
}
```

### Replacement Flow

1. User selects text
2. Assistant popover appears
3. User asks question/requests help
4. AI responds with suggestion
5. User clicks response to replace selection
6. Selection replaced, caret repositioned

## AI Summaries

**File:** `Note.swift` - `generateSummary()`

Auto-generated one-line summaries for notes.

### Generation Conditions

```swift
func canGenerateAISummary() -> Bool {
    if isEmpty { return false }
    if !contentHasChanged() { return false }  // Hash comparison
    if aiSummaryIsGenerating { return false }
    if model.availability != .available { return false }
    return true
}
```

### Summary Prompt

```swift
let instructions = """
    Write a single-line summary of the passage. State the core point directly.
    Do not mention the passage or the act of summarizing. No prefaces, labels,
    citations, or quotes. Preserve key entities and facts. Output exactly one
    sentence with no line breaks.
    """
```

### Trigger Points

- Note deselection in NoteList
- Toggle to preview mode in editor
- File import completion

## Magic Chat

**Files:** `ChatWindow.swift`, `MagicChatPrompt.swift`

Full chat interface with RAG support.

### Feature Flag

```swift
// ChatFeatureFlagEnabled.swift
let chatFeatureFlagEnabled = true  // or false to disable
```

### Chat Data Types

```swift
enum Sender { case human, bot }

struct ConversationEntry: Identifiable {
    let id: UUID
    let sender: Sender
    let text: String
}
```

### RAG Integration

When `searchEnabled: true`, user queries trigger search:

```swift
let results = search.index.searchNatural(query: userMessage)
```

Results included in prompt as:
```
SOURCE EXCERPTS:
[search result 1]
[search result 2]
...
```

### Prompt Assembly

```swift
var fullPrompt = instructions ?? MAGIC_CHAT_PROMPT
fullPrompt += "\n\nUser query: \(userMessage)"

if let context = context {
    fullPrompt += "\n\nContext: \(context)"
}

if !searchResults.isEmpty {
    fullPrompt += "\n\nSOURCE EXCERPTS:\n" + searchResults.joined(separator: "\n")
}

if useHistory {
    fullPrompt += "\n\nPrevious conversation:\n" + history
}
```

### Response Processing

Responses are unwrapped from code fences:

```swift
let cleanResponse = unwrapMarkdownFence(response.content)
```

**File:** `UnwrapMarkdownFence.swift`
- Removes ` ```...``` ` wrapper
- Trims one trailing newline

## Prompts Directory

**Location:** `TakeNote/Prompts/`

| File | Constant | Purpose |
|------|----------|---------|
| `MagicFormatPrompt.swift` | `MAGIC_FORMAT_PROMPT` | Plain text to Markdown |
| `MagicAssistantPrompt.swift` | `MAGIC_ASSISTANT_PROMPT` | Selected text help |
| `MagicChatPrompt.swift` | `MAGIC_CHAT_PROMPT` | General chat |

## Chunking for RAG

**File:** `Chunking.swift`

`WindowChunker` splits text for embedding:

```swift
static func chunk(text: String, windowSize: Int = 1000) -> [String]
```

- Splits at whitespace boundaries
- Approximately `windowSize` characters per chunk
- Preserves word integrity
