# Phase 0014: Fix Magic Chat Typing Indicator

## Intent

Phase 0013 introduced a three-dot animated typing indicator in Magic Chat but shipped with two defects. This Phase corrects both.

**Defect 1 — Indicator outside the bubble:** The empty bot `ConversationEntry` (text: `""`) is appended before streaming begins, causing `MessageBubble` to render a visible but empty glass-effect bubble. The standalone `HStack` of dots then renders below that empty bubble as a separate layout element. The dots must appear inside the glass-effect bubble, not alongside it.

**Defect 2 — Animation does not cycle:** The current animation uses `withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: true))` driven by a single `dotPhase` Double toggling between 0 and 1. This produces at most a single pass and does not guarantee a continuously cycling wave. The animation must loop indefinitely with each dot pulsing in sequence until the first streaming token arrives.

Both defects are fixed by moving all typing indicator logic into `MessageBubble` (or a small `TypingIndicator` sub-view within that file), removing the standalone indicator and its state from `ChatWindow`, and implementing a `PhaseAnimator`-based or `TimelineView`-based continuous cycling wave.

## Scope

**In scope:**
- `TakeNote/Views/ChatWindow/MessageBubble.swift` — add typing indicator rendering inside the `bubble` computed property when `!isHuman && entry.text.isEmpty && !entry.isComplete`; move animation state here.
- `TakeNote/Views/ChatWindow/ChatWindow.swift` — remove the standalone `HStack` typing indicator (lines 196–218), remove `@State private var dotPhase` and the `@Environment(\.accessibilityReduceMotion) private var reduceMotion` property (both become unnecessary in ChatWindow once the indicator moves).
- `.ushabti/docs/ai-features.md` — update the Loading Indicator section and the Phase 0013 property table to reflect that the indicator and `reduceMotion`/`dotPhase` state now live in `MessageBubble`.

**Out of scope:**
- Any other visual or behavioral changes to Magic Chat.
- Changes to `ConversationEntry`, `Sender`, or any other data type.
- Version bump (Overseer handles this per L20 before marking the Phase complete).
- Any other file not listed above.

## Constraints

- **L01** — macOS 26 / iOS 26 minimum. No `#available` checks below those targets.
- **L09** — No new app-wide state managers. Animation state is local to the view (`@State` in `MessageBubble` or an extracted sub-view).
- **L17** — Builder must update `ai-features.md` when code changes affect a documented system.
- **Style** — Sub-view computed properties on view types use `UpperCamelCase`. Any extracted `TypingIndicator` view is named in `UpperCamelCase` and lives in `MessageBubble.swift` (one primary type per file, with small supporting types permitted in the same file per style guide).
- **L07** — No chat feature flag changes; this is a pure rendering fix.
- The fix must preserve `@Environment(\.accessibilityReduceMotion)` behavior: when reduce motion is enabled, show static (non-animated) dots.

## Acceptance criteria

- [ ] When waiting for the first streaming token, animated dots appear inside the bot message bubble (wrapped in the same glass-effect styling as other bot messages), with no empty bubble rendered alongside or above them.
- [ ] No standalone typing indicator `HStack` exists in `ChatWindow.swift`; the `dotPhase` state property and (if no longer needed) the `reduceMotion` environment property are removed from `ChatWindow`.
- [ ] The dots animation cycles continuously, with each dot scaling up and down in sequence, until the first token arrives and text begins populating the bubble.
- [ ] Animation stops and is replaced by streaming text as soon as `entry.text` becomes non-empty.
- [ ] `@Environment(\.accessibilityReduceMotion)` is respected — static dots are shown when reduce motion is enabled.
- [ ] `ai-features.md` accurately describes the updated indicator placement and which file owns the animation state.
- [ ] The app builds without errors or warnings introduced by these changes.

## Risks / notes

- `PhaseAnimator` and `TimelineView(.animation)` are both available at macOS 26 / iOS 26. Either approach is acceptable; Builder should choose whichever produces a cleaner, continuously looping wave effect. `PhaseAnimator` with three phases (one per dot leading) is a natural fit.
- `reduceMotion` in `ChatWindow` may also be used elsewhere or referenced in future work. Builder must verify it has no other usages in `ChatWindow.swift` before removing it; if it is used elsewhere in that file, leave it and only remove `dotPhase`.
- The `bubble` computed property in `MessageBubble` currently applies glass-effect styling. The typing indicator dots should render inside that styled container, matching the visual treatment of all bot bubbles.
