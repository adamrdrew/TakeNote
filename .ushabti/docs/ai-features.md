# AI Features

All inference uses Apple's on-device FoundationModels framework. `TakeNoteLanguageModels` defines the general chat model, content-tagging model for summaries, content-transformation model, and general fallback. Each call checks its model's availability. Unsupported devices retain the normal note-taking features.

## Magic Format

`MagicFormatter` is an `@Observable`, `@MainActor` service. Each request creates a fresh `LanguageModelSession`, checks cancellation and the input hash, and returns `MagicFormatterResult` (`inputHash`, `formattedText`, `didSucceed`, `wasCancelled`). Content transformation uses permissive transformation guardrails and retries with the general model when the transformation configuration is unsupported. Errors and the prompt's failure token leave the original note unchanged.

## Magic Assistant

The editor presents `ChatWindow` with the selected text as `context`, `MAGIC_ASSISTANT_PROMPT` as its instructions, `searchEnabled: false`, and `useHistory: false`. `ChatRequest` puts the selection and current request into the prompt before an empty response bubble is added. Assistant replies can replace the selection. The assistant has no search or note-creation tools.

## Magic Chat

The `MagicChatEnabled` Info.plist flag gates the Magic Chat UI. It does not gate search indexing or Magic Assistant.

Each response uses a fresh model session. The visible conversation is included in the request through `ChatRequest.prompt`; changing the tool set cannot discard prior turns. Apple's `SpotlightSearchTool` retrieves notes through Core Spotlight (see [Search System](search-system.md)). A per-response ID scopes streaming, tool callbacks, and source updates so cancelled or closed chats cannot mutate another turn.

`createNote` is offered only when the current prompt explicitly asks to create/save/write a note. The policy matches complete request words and rejects ordinary questions, instructions about how to create notes, and negated requests. The model instructions independently restrict creation to explicit requests. Prior conversation and retrieved notes cannot enable the write tool for the current turn. Successful creations go to Inbox and are indexed; failed saves remove the unsaved insertion.

Responses stream into their own message bubble. Search replies update source links and status. Context overflow triggers one summary-and-retry attempt using the content-tagging model, with its own availability check. A new chat or view disappearance cancels the response and search observer. Cancellation is also checked inside the creation tool.

## Automatic summaries

`Note.generateSummary()` uses content tagging and deterministic generation settings. A SHA-256 content hash avoids redundant generation; cancelled results are discarded. Empty or failed summaries do not overwrite a valid summary. Summaries appear in note lists and widget snapshots.

## Tests and runtime requirements

Regression tests cover explicit creation requests, read-only/negated requests, conversation continuity, and selected-text prompts without requiring Apple Intelligence. End-to-end model behavior requires an Apple Intelligence-capable device with the model downloaded and enabled; simulator results are insufficient to validate inference quality.
