# Steps

## S001: Add `Hashable` conformance to `SearchHit`

**Intent:** `ConversationEntry` must conform to `Hashable` (it already does), and with the addition of `sources: [SearchHit]`, `SearchHit` must also be `Hashable`. This unblocks the struct additions in S002.

**Work:**
- In `/TakeNote/Library/SearchIndexService.swift`, change the `SearchHit` declaration from `struct SearchHit: Identifiable` to `struct SearchHit: Identifiable, Hashable`.
- No body changes are required — all three fields (`id: Int64`, `noteID: UUID`, `chunk: String`) have synthesized `Hashable` conformance.

**Done when:** `SearchIndexService.swift` declares `struct SearchHit: Identifiable, Hashable` and the project compiles without errors.

---

## S002: Add `sources` and `isComplete` to `ConversationEntry`

**Intent:** Each bot `ConversationEntry` needs to carry its source `SearchHit` values so citation links can be rendered per-entry, and an `isComplete` flag to cleanly distinguish "streaming in progress" from "response finished" without text-emptiness heuristics.

**Work:**
- In `/TakeNote/Views/ChatWindow/ChatWindow.swift`, add two properties to `ConversationEntry`:
  ```swift
  var sources: [SearchHit] = []
  var isComplete: Bool = false
  ```
- Both must have default values of `[]` and `false` respectively so the existing `init(sender:text:)` call sites do not need updating.
- The `ConversationEntry` struct already conforms to `Identifiable, Hashable`. After S001, adding `[SearchHit]` to the struct body remains synthesizable.

**Done when:** `ConversationEntry` has `sources: [SearchHit] = []` and `isComplete: Bool = false`. Project compiles. Existing call sites (human entry append in `askQuestion()`, unavailability message in `generateResponse()`) do not require changes.

---

## S003: Add `@Query` and `noteTitle(for:)` to `ChatWindow`

**Intent:** `ChatWindow` needs access to `Note` objects to look up note titles for citation links. The established pattern (used in `NoteListHeader`) is `@Query() var allNotes: [Note]` on the view.

**Work:**
- In `ChatWindow.swift`, add the import for `SwiftData` (already imported) and add the query property:
  ```swift
  @Query() var allNotes: [Note]
  ```
- Add a private helper method:
  ```swift
  private func noteTitle(for noteID: UUID) -> String {
      allNotes.first(where: { $0.uuid == noteID })?.title ?? "Note"
  }
  ```
- Place `@Query` alongside the other `@State` / `@Environment` property declarations at the top of the struct.

**Done when:** `ChatWindow` has `@Query() var allNotes: [Note]` declared and the `noteTitle(for:)` helper method exists. Project compiles.

---

## S004: Disable input while generating

**Intent:** The `TextField` must be visually and functionally disabled while `responseIsGenerating` is `true`. The existing guard in `askQuestion()` prevents double-submission; this step adds the UI-level affordance.

**Work:**
- In `ChatWindow.swift`, locate the `HStack` that wraps the `TextField` in the input bar. Apply `.disabled(responseIsGenerating)` to the `HStack` (the outer pill-shaped container wrapping the `TextField`).
- The existing guard `guard !trimmed.isEmpty, !responseIsGenerating else { return }` in `askQuestion()` must remain unchanged — defense in depth.

**Done when:** The input `HStack` has `.disabled(responseIsGenerating)` applied. Sending a message visually disables the input field and the guard still exists.

---

## S005: Switch `generateResponse()` to streaming

**Intent:** Replace the single `session.respond(to:)` call with `session.streamResponse(to:)` so the bot response streams in progressively. The bot entry is appended before the loop starts so SwiftUI can render the bubble immediately. Sources are captured at question-ask time and passed to the bot entry at append time. `responseIsGenerating` is held `true` for the full loop duration and reset `false` only after exit (or on error).

**Work:**
- In `ChatWindow.swift`, update `askQuestion()` to capture `searchResults` at ask-time into a local `let capturedSources = searchResults` variable, so that the value is frozen before the async gap.
- Rewrite `generateResponse()` as follows (preserving the availability guard and the prompt assembly logic):
  1. Preserve the `guard SystemLanguageModel.default.availability == .available` block verbatim. On unavailability, append a bot entry with `isComplete: true` and `sources: []`, reset `responseIsGenerating = false`, and return.
  2. Remove the `session.isResponding` check (not meaningful before a request is made).
  3. Append a bot entry with `text: ""` and `sources: capturedSources` (passed in as a parameter from `askQuestion`) before the streaming loop.
  4. Record `let botIndex = conversation.count - 1`.
  5. Create a fresh `LanguageModelSession(instructions: modelInstructions)`.
  6. Call `session.streamResponse(to: assembledPrompt)` to get the stream.
  7. In a `do` block, iterate `for try await partial in stream` and assign `conversation[botIndex].text = partial` each iteration.
  8. After the loop, apply `unwrapMarkdownFence` to `conversation[botIndex].text` and set `conversation[botIndex].isComplete = true`.
  9. In the `catch` block, set `conversation[botIndex].text = "Something went wrong. Sorry."` and `conversation[botIndex].isComplete = true`.
  10. After the `do/catch`, set `responseIsGenerating = false`.
- Update the `Task { await generateResponse() }` call in `askQuestion()` to pass `capturedSources` to `generateResponse(sources:)` — change the function signature to `private func generateResponse(sources: [SearchHit]) async`.

**Done when:** `generateResponse(sources:)` uses `streamResponse(to:)`, appends the bot entry before the loop, mutates `text` in-place per partial, sets `isComplete = true` after the loop or on error, and sets `responseIsGenerating = false` after the `do/catch`. The availability guard is preserved. A fresh `LanguageModelSession` is created inside the function. Project compiles.

---

## S006: Replace "Thinking..." indicator with animated dots

**Intent:** With streaming, the bot entry is appended immediately (before any tokens arrive), so the old `AIMessage("Thinking...")` block — gated on `responseIsGenerating` — is now meaningless. Replace it with a three-dot animated pulse that shows only when the last conversation entry is a bot entry with empty text (waiting for the first token).

**Work:**
- In `ChatWindow.swift`, remove the existing block:
  ```swift
  if responseIsGenerating {
      AIMessage(message: "Thinking...", font: .headline)
  }
  ```
- Add a `@State private var dotPhase: Double = 0` property to `ChatWindow`.
- Replace the removed block with:
  ```swift
  if let lastEntry = conversation.last, lastEntry.sender == .bot, lastEntry.text.isEmpty {
      HStack(spacing: 4) {
          ForEach(0..<3, id: \.self) { i in
              Circle()
                  .fill(Color.secondary.opacity(0.6))
                  .frame(width: 8, height: 8)
                  .scaleEffect(dotPhase > Double(i) * (1.0 / 3.0) ? 1.3 : 1.0)
                  .animation(
                      reduceMotion ? nil : .easeInOut(duration: 0.4).delay(Double(i) * 0.15),
                      value: dotPhase
                  )
          }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .onAppear {
          guard !reduceMotion else { return }
          withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: true)) {
              dotPhase = 1.0
          }
      }
  }
  ```
- Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to `ChatWindow` (following the pattern in `MovingGradientForeground`).
- The dots disappear automatically as soon as `conversation.last?.text` becomes non-empty (the first streaming token arrives and mutates the entry's text in-place).

**Done when:** The `AIMessage("Thinking...")` block is removed. The three-dot indicator appears when the last entry is a bot entry with empty text and disappears when the first token arrives. `reduceMotion` is respected.

---

## S007: Update `MessageBubble` to render citation links

**Intent:** After streaming completes (`isComplete == true`), each bot entry's `sources` field contains the `SearchHit` values from the FTS query. `MessageBubble` should render one `Link` per unique source note below the bot bubble, in `Color.takeNotePink` with `.caption` font.

**Work:**
- In `/TakeNote/Views/ChatWindow/MessageBubble.swift`, update the struct declaration to accept `notes: [Note]`:
  ```swift
  struct MessageBubble: View {
      let entry: ConversationEntry
      var onBotMessageClick: ((String) -> Void)?
      var notes: [Note] = []
  ```
- Add a `private func noteTitle(for noteID: UUID) -> String` helper (same pattern as `ChatWindow.noteTitle(for:)`).
- Add a `private func deduplicated(_ hits: [SearchHit]) -> [SearchHit]` helper that filters by unique `noteID` using a `Set<UUID>`.
- In the `body`, inside the existing `VStack(alignment: isHuman ? .trailing : .leading, spacing: 6)`, after the Accept button row (if present), add the citation links block:
  ```swift
  if !isHuman && entry.isComplete && !entry.sources.isEmpty {
      let uniqueSources = deduplicated(entry.sources)
      if !uniqueSources.isEmpty {
          HStack(spacing: 6) {
              ForEach(uniqueSources, id: \.noteID) { hit in
                  if let url = URL(string: "takenote://note/\(hit.noteID.uuidString)") {
                      Link(noteTitle(for: hit.noteID), destination: url)
                          .font(.caption)
                          .foregroundStyle(Color.takeNotePink)
                  }
              }
              Spacer(minLength: 0)
          }
          .padding(.horizontal, 4)
      }
  }
  ```
- Update the `MessageBubble` call site in `ChatWindow.body` to pass `notes: allNotes`:
  ```swift
  MessageBubble(entry: entry, onBotMessageClick: onBotMessageClick, notes: allNotes)
  ```
- Add `import SwiftData` to `MessageBubble.swift` if not already present (needed for `Note` type reference; `Note` is a SwiftData `@Model`).

**Done when:** `MessageBubble` accepts `notes: [Note]`, renders deduplicated citation links in `Color.takeNotePink` at `.caption` font after `isComplete` is `true`, and the call site in `ChatWindow` passes `allNotes`. No citations render when `isHuman`, `!entry.isComplete`, or `entry.sources.isEmpty`.

---

## S008: Update `ai-features.md`

**Intent:** Laws L17 and L19 require that `ai-features.md` be updated to reflect all code changes made in this Phase before the Phase can be declared complete. This is a hard gate.

**Work:**
- In `.ushabti/docs/ai-features.md`, update the Magic Chat section to reflect:
  - `ConversationEntry` now has `sources: [SearchHit] = []` and `isComplete: Bool = false`
  - `searchResults` captured at ask-time and associated per conversation entry via `sources`
  - `generateResponse(sources:)` uses `session.streamResponse(to:)` instead of `session.respond(to:)`
  - The bot entry is appended before the streaming loop begins; `text` is mutated in-place per partial
  - `responseIsGenerating` is held `true` through the entire streaming loop; reset `false` after loop exit (including error paths)
  - Input `TextField` is disabled while `responseIsGenerating` is `true`
  - Three-dot animated loading indicator shown when the last entry is a bot entry with empty text; hidden once the first token arrives; respects `accessibilityReduceMotion`
  - `isComplete` is set `true` after the streaming loop finishes (or on error), gating citation display
  - Citation links rendered in `MessageBubble` below the bot bubble: one per unique source note, `Color.takeNotePink`, font `.caption`, opens via `takenote://note/<UUID>`
  - `MessageBubble` now accepts `notes: [Note]` for title lookup; includes `deduplicated(_:)` helper
  - `ChatWindow` now has `@Query() var allNotes: [Note]` and `noteTitle(for:)` helper
  - `SearchHit` now conforms to `Hashable`
  - Update the Data Types table in the Magic Chat section accordingly

**Done when:** `ai-features.md` accurately and completely describes the updated Magic Chat implementation with no references to the old `respond(to:)` call, the old `AIMessage("Thinking...")` block, or the old `ConversationEntry` shape.

---

## S009: Fix stale Feature Flag section in ai-features.md

**Intent:** The Feature Flag section of `ai-features.md` still contains the pre-Phase-0011 statement "search indexing is skipped" when `chatFeatureFlagEnabled` is `false`. This directly contradicts L07 (FTS indexing is always-on and must not be gated on the chat feature flag) and was not corrected during S008. The docs must accurately reflect the current architecture.

**Work:**
- In `.ushabti/docs/ai-features.md`, locate the line:
  ```
  When `false`: the chat window never opens, search indexing is skipped, and the Chat toolbar button is hidden.
  ```
- Replace it with text that accurately describes current behavior, such as:
  ```
  When `false`: the Chat window never opens and the Chat toolbar button is hidden. FTS search indexing continues to run unconditionally (see L07) — the feature flag gates only the Chat UI surfaces, not the search index.
  ```

**Done when:** The Feature Flag section of `ai-features.md` no longer states that search indexing is skipped when the flag is `false`, and instead accurately describes that FTS indexing is unconditional.

---

## S010: Bump CURRENT_PROJECT_VERSION and MARKETING_VERSION in project.pbxproj

**Intent:** L20 requires that Overseer increment both version fields before declaring any Phase complete. The Phase 0013 implementation did not bump the version numbers; they remain at the same values as master (`CURRENT_PROJECT_VERSION = 15`, `MARKETING_VERSION = 1.1.11`).

**Work:**
- In `TakeNote.xcodeproj/project.pbxproj`, update all four occurrences of:
  - `CURRENT_PROJECT_VERSION = 15;` → `CURRENT_PROJECT_VERSION = 16;`
  - `MARKETING_VERSION = 1.1.11;` → `MARKETING_VERSION = 1.1.12;`
- All four occurrences of each field (Debug and Release configurations for the TakeNote and NewNoteControl targets) must be updated to the same value.

**Done when:** All four `CURRENT_PROJECT_VERSION` entries read `16` and all four `MARKETING_VERSION` entries read `1.1.12` in `TakeNote.xcodeproj/project.pbxproj`.
