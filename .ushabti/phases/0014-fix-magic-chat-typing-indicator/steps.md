# Steps

## S001: Move typing indicator into MessageBubble

**Intent:** Render the three-dot typing indicator inside the bot glass-effect bubble rather than as a standalone element in the `LazyVStack`, eliminating the empty-bubble-plus-dots defect.

**Work:**
- In `MessageBubble.swift`, update the `bubble` computed property to branch on `!isHuman && entry.text.isEmpty && !entry.isComplete`. When that condition is true, render the three dots inside the same padding and glass-effect styling as the text bubble, rather than `Text(entry.text)`.
- Optionally extract a small `TypingIndicator` private struct (or private computed sub-view `TypingDots`) within `MessageBubble.swift` to contain the dot layout and animation logic. If extracted as a struct, name it `TypingIndicator`. If a computed property, name it `TypingDots` (UpperCamelCase per style).
- The dots must sit inside the padding (`.padding(.vertical, 10).padding(.horizontal, 12)`) and glass-effect modifier that wraps the existing `Text`, so they inherit the same visual treatment as all bot bubbles.
- Read `@Environment(\.accessibilityReduceMotion)` inside `MessageBubble` (or the extracted view) to control animation.

**Done when:** A bot entry with `text == ""` and `isComplete == false` renders a bot-styled bubble containing three dots, with no separate empty bubble visible.

## S002: Implement continuously cycling dot animation

**Intent:** Replace the one-shot `dotPhase` toggle with a genuine continuously looping wave animation, satisfying the requirement that dots keep cycling until text arrives.

**Work:**
- Implement the cycling animation using `PhaseAnimator` (preferred) or `TimelineView(.animation)` within `MessageBubble.swift` or the extracted `TypingIndicator` view.
- The animation should produce a sequential wave: dot 0 scales up, then dot 1, then dot 2, then repeats from dot 0, continuously, with each dot returning to its base scale before the next one rises.
- When `reduceMotion` is `true`, render all three dots at uniform scale with no animation applied.
- The animation must stop naturally when the view disappears (i.e., when `entry.text` becomes non-empty and the indicator branch is no longer rendered, SwiftUI tears down the view and animation stops).

**Done when:** Three dots cycle in a visible wave pattern that loops without stopping while `entry.text` is empty and `entry.isComplete` is false; reduce-motion path shows static dots.

## S003: Remove standalone typing indicator from ChatWindow

**Intent:** Clean up `ChatWindow.swift` by removing the now-redundant standalone indicator `HStack` and its associated state, leaving `ChatWindow` free of typing-indicator concerns.

**Work:**
- In `ChatWindow.swift`, delete the `if let lastEntry` block (lines 196–218 in the current file) that renders the standalone three-dot `HStack` in the `LazyVStack`.
- Remove `@State private var dotPhase: Double = 0` from `ChatWindow`.
- Check whether `@Environment(\.accessibilityReduceMotion) private var reduceMotion` is referenced anywhere else in `ChatWindow.swift`. If the only usage was in the now-deleted typing indicator block, remove the property. If it is used elsewhere, leave it.
- Verify that the `onChange(of: conversation.count)` scroll logic and all other `LazyVStack` content are unaffected.

**Done when:** `ChatWindow.swift` compiles without the standalone typing indicator code; `dotPhase` is gone; `reduceMotion` is removed if it had no other usages; the rest of the chat UI is visually and behaviorally unchanged.

## S004: Update ai-features.md

**Intent:** Keep documentation accurate per L17 and L19. The Loading Indicator section and the Phase 0013 property tables must reflect the new implementation location.

**Work:**
- In `.ushabti/docs/ai-features.md`, update the "Loading Indicator (Animated Dots)" section under Magic Chat to describe the new behavior: the indicator renders inside the `MessageBubble` when `entry.text.isEmpty && !entry.isComplete`, the animation is a continuous cycling wave implemented via `PhaseAnimator` (or `TimelineView`) in `MessageBubble`, and `reduceMotion` is read in `MessageBubble`.
- Update the "ChatWindow Properties Added (Phase 0013)" table: remove the `dotPhase` row and the `reduceMotion` row if those properties were removed from `ChatWindow`. Note that these are now owned by `MessageBubble`.
- Update the "MessageBubble Changes (Phase 0013)" table to document the typing indicator logic addition: the `bubble` property now renders dots when `entry.text.isEmpty && !entry.isComplete`, and animation state lives in `MessageBubble`.
- Remove or update any statement that says `ChatWindow` holds `@State private var dotPhase` to drive the animation.

**Done when:** `ai-features.md` accurately describes where the typing indicator is rendered and which file owns animation state, with no stale references to `ChatWindow` owning `dotPhase`.

## S005: Fix PhaseAnimator to cycle continuously: replace trigger-based init with no-trigger init

**Intent:** The current `PhaseAnimator(phases, trigger: true)` call uses a constant trigger that never changes. Per the `PhaseAnimator` API, the trigger-based initializer only restarts the animation when the trigger value changes; with `trigger: true`, the animation cycles through the phases exactly once on appearance and then stops. Defect 2 (animation does not cycle) is therefore not fixed. The no-trigger `PhaseAnimator(phases)` initializer cycles through all phases repeatedly without stopping, which is the required behavior.

**Work:**
- In `TakeNote/Views/ChatWindow/MessageBubble.swift`, in `TypingIndicator.body`, replace:
  ```swift
  PhaseAnimator(phases, trigger: true) { leadingDot in
  ```
  with:
  ```swift
  PhaseAnimator(phases) { leadingDot in
  ```
- Remove the `private let phases: [Int] = [0, 1, 2]` stored property if desired and inline the array literal, or keep it — either is acceptable. The critical change is removing `trigger: true`.
- Verify the `animation:` closure is retained unchanged.
- The `reduceMotion` branch and `staticDots` computed property are correct and must not be changed.

**Done when:** `TypingIndicator` uses `PhaseAnimator(phases)` (no trigger), the three dots cycle continuously and indefinitely while the view is on screen, and the file compiles without errors.
