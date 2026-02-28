# Review: Phase 0014 — Fix Magic Chat Typing Indicator

## Summary

GREEN. All five steps are complete and correct. The kicked-back defect (S005: `PhaseAnimator` with constant trigger) is fixed. All acceptance criteria pass. All laws pass. Docs are reconciled. Version bumped to `CURRENT_PROJECT_VERSION = 17` / `MARKETING_VERSION = 1.1.13` per L20.

## Verified

**S001 — Move typing indicator into MessageBubble: PASS**

`MessageBubble.bubble` branches on `!isHuman && entry.text.isEmpty && !entry.isComplete`. When true, renders `TypingIndicator()` inside `.padding(.vertical, 10).padding(.horizontal, 12)` and the same `.glassEffect(.regular.tint(.secondary.opacity(0.2)).interactive(), in: .rect(cornerRadius: 16.0))` and `.shadow` modifiers used by the text bubble. No empty bubble can appear alongside the dots.

**S002 — Continuously cycling dot animation: PASS**

`TypingIndicator` in `MessageBubble.swift` at line 24 uses:

```swift
PhaseAnimator(phases) { leadingDot in
    dotsRow(leadingDot: leadingDot)
} animation: { _ in
    .easeInOut(duration: 0.4)
}
```

The no-trigger `PhaseAnimator(phases:content:animation:)` initializer cycles through phases `[0, 1, 2]` indefinitely. `trigger: true` is gone. Defect 2 is resolved.

**S003 — Remove standalone typing indicator from ChatWindow: PASS**

`ChatWindow.swift` has no `dotPhase`, no `reduceMotion`, and no standalone `if let lastEntry` HStack. Only the `ForEach` over `conversation` entries and the `"BOTTOM"` spacer remain in the scroll area. `onChange(of: conversation.count)` scroll logic is untouched.

**S004 — Update ai-features.md: PASS**

Loading Indicator section accurately describes `TypingIndicator` as a private struct in `MessageBubble.swift`, using `PhaseAnimator` phases `[0, 1, 2]` for a continuously looping wave, reading `@Environment(\.accessibilityReduceMotion)` directly, with animation state entirely in `MessageBubble.swift`. ChatWindow Properties table correctly notes that `dotPhase` and `reduceMotion` were removed in Phase 0014. Phase 0014 MessageBubble changes table is present and accurate.

**S005 — Fix PhaseAnimator trigger: PASS**

`PhaseAnimator(phases)` confirmed at `MessageBubble.swift` line 24. No `trigger:` argument. The animation cycles continuously as required.

**Laws: PASS (all checked)**

- L01: No `#available` checks below macOS 26 / iOS 26. Deployment targets `26.0` confirmed in project file. Confirmed.
- L05: AI availability gate in `generateResponse(sources:)` checks `SystemLanguageModel.default.availability == .available`. Confirmed unchanged.
- L06: `LanguageModelSession` created fresh per `generateResponse` call. No stored session. Confirmed.
- L07: No FTS gating. No chat feature flag changes. Confirmed.
- L09: `TypingIndicator` uses `PhaseAnimator` with no stored `@State`. `@Environment(\.accessibilityReduceMotion)` is read-only environment access. Confirmed.
- L17/L18/L19: `ai-features.md` updated and accurate. Confirmed.
- L20: `CURRENT_PROJECT_VERSION` incremented 16 → 17. `MARKETING_VERSION` incremented `1.1.12` → `1.1.13`. All four occurrences of each field updated. Confirmed.

**Style: PASS**

`TypingIndicator` is `UpperCamelCase`, `private`, file-local in `MessageBubble.swift`. `staticDots` and `dotsRow(leadingDot:)` follow `lowerCamelCase`. Confirmed.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. Phase 0014 is complete. Weighed and found true.

Version bumped: `CURRENT_PROJECT_VERSION = 17`, `MARKETING_VERSION = 1.1.13`.

Recommend handing off to Ushabti Scribe for the next Phase.
