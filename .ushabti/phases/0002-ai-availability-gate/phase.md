# Phase 0002: AI Availability Gate in ChatWindow

## Intent

Fix the L05 law violation in `ChatWindow.generateResponse()` (R004). This method creates a `LanguageModelSession` with no check that Apple Intelligence is available. On a device where Apple Intelligence is unavailable, this produces a runtime error. The fix adds an availability guard before any `LanguageModelSession` instantiation and handles the unavailable case gracefully in the UI.

## Scope

**In scope:**
- Add an Apple Intelligence availability check inside `ChatWindow.generateResponse()` before the `LanguageModelSession` is created
- Handle the unavailable case by surfacing a user-visible message in the conversation rather than silently failing or crashing
- Update `ai-features.md` to remove the "Known Issue" note documenting this violation

**Out of scope:**
- Changes to any other file or view
- Changing how the Chat toolbar button is shown/hidden (that is already gated correctly in `MainWindow` via `chatFeatureFlagEnabled && chatEnabled`)
- Fixing R005, R007, R009, R010, R011 — those are handled in Phase 0003 and Phase 0004

## Constraints

- L05: Every `LanguageModelSession` instantiation MUST be preceded by an availability check
- L04: The check must use the FoundationModels availability API; no third-party fallback is permitted
- Style: `ChatWindow` does not have access to `TakeNoteVM` via the SwiftUI environment in all contexts it can be presented (standalone chat window, Magic Assistant popover in NoteEditor). The canonical check `TakeNoteVM.aiIsAvailable` is therefore not directly accessible. The correct approach is to check `SystemLanguageModel.default.availability == .available` directly — consistent with how `MagicFormatter.magicFormat()` checks `languageModel.isAvailable` directly, and consistent with how `Note.canGenerateAISummary()` checks availability on the model object without VM access. A local `let languageModel = SystemLanguageModel.default` property may be added to `ChatWindow` if helpful, following the pattern in `TakeNoteVM` and `MagicFormatter`.
- Style: Unavailability should produce a visible, friendly message in the conversation rather than a silent no-op, so the user understands why no response appeared

## Acceptance criteria

- `ChatWindow.generateResponse()` checks AI availability before creating a `LanguageModelSession`
- When AI is unavailable, the method exits without creating a session and appends a bot conversation entry with a human-readable explanation (e.g., "Apple Intelligence is not available on this device.")
- No `LanguageModelSession` is instantiated in `ChatWindow` on any code path where AI is unavailable
- The project builds successfully
- The "Known Issue: Missing AI Availability Gate (L05 Violation)" note in `.ushabti/docs/ai-features.md` is updated to reflect that this is now fixed

## Risks / notes

- This is a surgical, single-method change. The risk of regression is low.
- The unavailability message appended as a bot reply is consistent with the existing fallback message pattern (`"Something went wrong. Sorry."`) already in `generateResponse()`.
