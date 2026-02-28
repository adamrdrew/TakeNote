# Phase 0013: Magic Chat UX Improvements

## Intent

Improve the Magic Chat experience across four connected areas: progressive streaming of bot responses, disabling input during generation, an animated three-dot typing indicator while waiting for the first token, and citation links rendered under each bot response bubble. Together these changes make Magic Chat feel responsive and trustworthy — the user sees text arrive as it is generated, knows the input is locked while the model is working, and can navigate directly to source notes after each response.

All changes are confined to the ChatWindow feature surface and its supporting types. No schema changes, no new `@Model` types, no new services.

## Scope

**In scope:**
- Add `Hashable` conformance to `SearchHit` in `SearchIndexService.swift`
- Add `sources: [SearchHit]` and `isComplete: Bool` properties to `ConversationEntry` in `ChatWindow.swift`
- Add `@Query() var allNotes: [Note]` and a `noteTitle(for:)` helper to `ChatWindow`
- Disable the `TextField` (and its container) with `.disabled(responseIsGenerating)`
- Replace `session.respond(to:)` with `session.streamResponse(to:)` and mutate the bot entry's text in-place during the streaming loop
- Append the bot `ConversationEntry` before the streaming loop starts; set `isComplete = true` after the loop finishes
- Hold `responseIsGenerating = true` for the full duration of streaming; reset `false` only after the loop exits (including error paths)
- Replace the `AIMessage("Thinking...")` block with a three-dot animated pulse indicator gated on the last entry being a bot entry with empty text
- Respect `@Environment(\.accessibilityReduceMotion)` in the dots indicator (pattern already established in `MovingGradientForeground`)
- Update `MessageBubble` to accept `notes: [Note]` and render citation links below the bot bubble when `entry.isComplete && !entry.sources.isEmpty`
- Deduplicate sources by `noteID` before rendering links
- Update `.ushabti/docs/ai-features.md` to reflect all changes

**Out of scope:**
- Changes to `MagicChatPrompt.swift`
- Changes to any view other than `ChatWindow.swift` and `MessageBubble.swift`
- Schema changes to `Note`, `NoteContainer`, or `NoteLink`
- New `@Model` types
- New services or state managers
- Changes to the FTS indexing path

## Constraints

- **L04**: `streamResponse(to:)` is a method on `LanguageModelSession` (FoundationModels). No third-party LLM APIs.
- **L05**: The `guard SystemLanguageModel.default.availability == .available` block at the top of `generateResponse()` must be preserved verbatim.
- **L06**: A fresh `LanguageModelSession` must be created inside `generateResponse()` per invocation. It must not be stored as a persistent property.
- **L07**: No new chat UI surfaces are introduced; no FTS indexing path is gated on `chatFeatureFlagEnabled`. No additional gating needed.
- **L09**: No new `@Observable` or `ObservableObject` state managers. `@Query` is a SwiftData property wrapper on a SwiftUI view, not a state manager.
- **L17/L19**: `ai-features.md` must be updated before the Phase is declared complete. This is a hard gate.
- **Style**: Sub-view computed properties on entry types use `UpperCamelCase`. `EnvironmentKey` key structs are `private` and file-local. Use `os.Logger` not `print()` for new logging (no new logging is required in this Phase).

## Acceptance criteria

- [ ] Sending a message disables the input field and keeps it disabled until the response finishes streaming
- [ ] While waiting for the first streaming token, three animated dots appear in the bot message position (left-aligned)
- [ ] Dots disappear as soon as the first text content begins streaming in
- [ ] Bot response text streams in progressively, token by token
- [ ] After streaming completes, citation links appear below the bot bubble — one link per unique source note
- [ ] Citation links use `Color.takeNotePink`, font `.caption`
- [ ] Tapping a citation link navigates to the correct note via `takenote://note/<UUID>`
- [ ] When `searchEnabled` is `false` (Magic Assistant mode), no citation row appears
- [ ] When sources are empty or all deduplicate away, no citation row renders
- [ ] Citations are not shown while streaming is in progress (`isComplete` gate)
- [ ] `responseIsGenerating` is `false` after streaming ends, including on error paths
- [ ] L05 availability guard is preserved in `generateResponse()`
- [ ] L06 is respected: fresh `LanguageModelSession` per `generateResponse()` invocation
- [ ] `SearchHit` conforms to `Hashable`
- [ ] `ConversationEntry` has `sources: [SearchHit] = []` and `isComplete: Bool = false`
- [ ] `ai-features.md` accurately describes the updated implementation

## Risks / notes

- `session.streamResponse(to:)` returns a `ResponseStream` (`AsyncSequence`) where each element is a cumulative partial string (not a delta). Assigning each partial snapshot directly to `conversation[botIndex].text` is correct — do not append, assign.
- The scroll trigger in `ChatWindow.body` currently fires on `onChange(of: conversation.count)`. With streaming, `conversation.count` only changes when the bot entry is first appended. Progressive text updates do not change the count. This is acceptable for this Phase — the scroll-to-bottom on token arrival is out of scope. Do not add an additional `onChange` trigger without explicit instruction.
- `session.isResponding` check after session creation in the current code can be removed as part of the streaming refactor — it is not meaningful before any request is made.
- The `@Query() var allNotes: [Note]` added to `ChatWindow` follows the existing pattern in `NoteListHeader`. Because `ChatWindow` is used both as a standalone window and as a popover, the `@Query` will be active in both contexts, which is correct and harmless.
