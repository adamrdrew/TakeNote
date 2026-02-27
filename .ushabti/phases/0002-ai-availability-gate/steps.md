# Steps

## S001: Add AI availability gate to ChatWindow.generateResponse

**Intent:** Prevent `LanguageModelSession` instantiation when Apple Intelligence is unavailable, satisfying L05.

**Work:**
- In `TakeNote/Views/ChatWindow/ChatWindow.swift`:
  - Add a local `let languageModel = SystemLanguageModel.default` property to `ChatWindow` (following the pattern in `TakeNoteVM` and `MagicFormatter`), or perform the check inline in `generateResponse()`
  - At the start of `generateResponse()`, before `let session = LanguageModelSession(...)`, add a guard that checks `languageModel.availability == .available` (or equivalent `isAvailable` property if present on the type)
  - If AI is not available: set `responseIsGenerating = false`, append a `ConversationEntry(sender: .bot, text: "Apple Intelligence is not available on this device.")` to `conversation`, and return early
  - The existing `LanguageModelSession` creation and the rest of the method body executes only when AI is confirmed available

**Done when:** `generateResponse()` contains an availability check that prevents `LanguageModelSession` instantiation when AI is unavailable; the guard is the first substantive action in the function body after variable setup.

---

## S002: Update ai-features.md to reflect the fix

**Intent:** Remove the documented known-issue note and keep docs accurate (required by L17/L18/L19).

**Work:**
- In `.ushabti/docs/ai-features.md`, find the "Known Issue: Missing AI Availability Gate (L05 Violation)" subsection under "Magic Chat"
- Remove the subsection entirely or replace it with a note confirming the gate is now in place
- Update the "Behavior" paragraph in the ChatWindow section if it does not yet mention the availability check

**Done when:** `ai-features.md` no longer documents an L05 violation for `ChatWindow`; the availability gate is described as present.
