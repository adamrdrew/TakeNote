# Review: Phase 0013 — Magic Chat UX Improvements

## Summary

Eight of eight steps are implemented and correct. The core implementation — streaming, input locking, animated dots, citation links, and all supporting structural changes — is complete, accurate, and law-compliant. Two items block the Phase from being declared complete: a stale, law-contradicting sentence in `ai-features.md`, and the required version bump required by L20 that was not applied.

## Verified

**S001 — SearchHit Hashable conformance**
`SearchIndexService.swift` line 12: `struct SearchHit: Identifiable, Hashable`. All three fields have synthesized conformance. Correct.

**S002 — ConversationEntry fields**
`ChatWindow.swift` lines 21-22: `var sources: [SearchHit] = []` and `var isComplete: Bool = false`. Default values correct; existing `init(sender:text:)` call sites unaffected. Correct.

**S003 — @Query and noteTitle helper**
`ChatWindow.swift` line 34: `@Query() var allNotes: [Note]`. Lines 124-126: `private func noteTitle(for noteID: UUID) -> String` with correct UUID lookup and `"Note"` fallback. Correct.

**S004 — Input disabled while generating**
`ChatWindow.swift` line 258: `.disabled(responseIsGenerating)` applied to the inner `HStack` wrapping the `TextField`. The `askQuestion()` guard at line 58 is preserved. Correct.

**S005 — Streaming implementation**
`ChatWindow.swift` lines 128-165:
- L05 availability guard preserved verbatim (lines 129-135).
- Fresh `LanguageModelSession` created inside the function, not stored (line 151; L06 respected).
- Bot entry appended with `text: ""` and `sources: sources` before the streaming loop (lines 140-143).
- `session.streamResponse(to:)` used (line 152).
- `partial.content` correctly assigned (line 156 — the post-build fix that uses `.content` on the `ResponseStream.Snapshot` object).
- `unwrapMarkdownFence` applied and `isComplete = true` set after the loop (lines 158-159).
- Error path sets text and `isComplete = true` (lines 161-162).
- `responseIsGenerating = false` set after `do/catch` (line 165), not inside it.
- The unavailability path also sets `isComplete: true` and resets `responseIsGenerating` (lines 131-133).
All correct. L04, L05, L06 all respected.

**S006 — Animated dots indicator**
`ChatWindow.swift` lines 196-218: Three-dot indicator gated on `conversation.last?.sender == .bot && conversation.last?.text.isEmpty`. `reduceMotion` respected at lines 204 and 213. `dotPhase` state at line 51. No `AIMessage("Thinking...")` remains in the file. Correct.

**S007 — MessageBubble citation links**
`MessageBubble.swift`:
- `import SwiftData` at line 7.
- `var notes: [Note] = []` at line 13.
- `noteTitle(for:)` at lines 73-75.
- `deduplicated(_:)` at lines 77-80 using `Set<UUID>` insertion.
- Citation links block at lines 50-65: gated on `!isHuman && entry.isComplete && !entry.sources.isEmpty`, deduplicated before rendering, `Color.takeNotePink`, `.font(.caption)`, `takenote://note/<UUID>` URL scheme, `Spacer(minLength: 0)` for left alignment.
- Call site in `ChatWindow.swift` line 189 passes `notes: allNotes`.
When `searchEnabled` is `false`, `searchResults` stays `[]` (initial value) and `capturedSources` is `[]`, so no citations ever render — acceptance criterion met.
Correct.

**S008 — ai-features.md Magic Chat section**
The Magic Chat section is thoroughly and accurately updated. Data Types table, Session Lifecycle and Streaming, Input Locking, Loading Indicator, AI Availability Gate, Citation Links, and new properties tables all correctly describe the implementation. The old `respond(to:)` reference, `AIMessage("Thinking...")` block, and old `ConversationEntry` shape are all absent from this section.

**Laws verified:**
- L04: No third-party LLM APIs.
- L05: Availability guard present in `generateResponse(sources:)`.
- L06: Fresh `LanguageModelSession` per call; no stored session.
- L07: No new FTS indexing guards added; no new ungated chat UI surfaces introduced.
- L09: No new `@Observable` state managers introduced; `@Query` is a SwiftUI view property wrapper, not a state manager.
- L13: `SearchIndexService.index` remains `SearchIndex` (FTS5).
- L17/L18/L19: ai-features.md updated — with one defect noted below.

## Issues

### ISSUE 1 — Stale, law-contradicting sentence in ai-features.md Feature Flag section (Blocking)

`ai-features.md` line 20 (in the "Feature Flag: Magic Chat" section, which was not part of S008's update) still reads:

> When `false`: the chat window never opens, **search indexing is skipped**, and the Chat toolbar button is hidden.

This statement is inaccurate. As of Phase 0011, FTS indexing is unconditional — it is not gated on `chatFeatureFlagEnabled`. L07 explicitly states that "FTS indexing MUST run unconditionally, regardless of the value of `chatFeatureFlagEnabled`." The Builder updated the Magic Chat section but did not correct this pre-existing stale line in the Feature Flag section. L18 and L19 require all docs to be reconciled with the codebase before the Phase is declared complete. A doc that contradicts a law is not reconciled.

**Required correction:** Update the Feature Flag section to accurately state that the flag gates only the Chat UI surfaces, not FTS indexing.

### ISSUE 2 — Version numbers not incremented (Blocking)

L20 requires that `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` be incremented before any Phase is declared complete. All four occurrences of each field in `TakeNote.xcodeproj/project.pbxproj` remain at the master-branch values:
- `CURRENT_PROJECT_VERSION = 15` (must become `16`)
- `MARKETING_VERSION = 1.1.11` (must become `1.1.12`)

This is a hard gate. The Phase cannot be declared complete until both fields are updated in all four configurations.

## Required follow-ups

- **S009:** Fix stale Feature Flag section in `ai-features.md` — correct "search indexing is skipped" to accurately reflect that FTS indexing is unconditional. See `steps.md` for specific work.
- **S010:** Bump `CURRENT_PROJECT_VERSION` from 15 to 16 and `MARKETING_VERSION` from `1.1.11` to `1.1.12` in all four configurations in `TakeNote.xcodeproj/project.pbxproj`. See `steps.md` for specific work.

## Re-review: S009 and S010

**S009 — Feature Flag section corrected**
`.ushabti/docs/ai-features.md` line 20 now reads:

> When `false`: the Chat window never opens and the Chat toolbar button is hidden. FTS search indexing continues to run unconditionally (see L07) — the feature flag gates only the Chat UI surfaces, not the search index.

The stale "search indexing is skipped" claim is gone. The text accurately reflects the L07 architecture. No other instances of the stale language were found. Correct.

**S010 — Version numbers incremented**
All four occurrences of `CURRENT_PROJECT_VERSION` in `TakeNote.xcodeproj/project.pbxproj` read `16` (lines 432, 496, 556, 600). All four occurrences of `MARKETING_VERSION` read `1.1.12` (lines 465, 529, 576, 620). Both fields updated in Debug and Release configurations for both the TakeNote and NewNoteControl targets. Correct per L20.

## Decision

GREEN. Both previously blocking defects are resolved. S009 corrected the law-contradicting Feature Flag section in `ai-features.md`. S010 applied the required version bump to all four configurations. All ten steps are implemented and verified. All acceptance criteria are met. All laws (L04, L05, L06, L07, L09, L13, L17, L18, L19, L20) are satisfied. The Phase is weighed and found true.
