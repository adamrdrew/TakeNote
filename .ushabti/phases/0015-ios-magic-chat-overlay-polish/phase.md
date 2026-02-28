# Phase 0015: iOS Magic Chat Overlay Polish

## Intent

Polish the Magic Chat overlay on iOS with four targeted UX improvements: dismiss the sheet when a citation link is tapped, add an empty-state placeholder, add a custom title bar with a centered "MagicChat" label and New Chat button, and animate the title color during response generation. All changes are strictly iOS-only; macOS behavior is unaffected.

## Scope

**In scope:**
- Dismiss the iOS chat sheet/popover when a `takenote://note/<UUID>` citation link is tapped
- Empty state placeholder (centered, gray) displayed when `conversation` is empty; disappears on first send
- iOS-only title bar inside `ChatWindow` with centered "MagicChat" text in `Color.takeNotePink` and a New Chat button on the right
- Animated color cycling (pink → orange → purple → blue) for the "MagicChat" title text while `responseIsGenerating == true`; returns to static `Color.takeNotePink` when idle
- `accessibilityReduceMotion` respected: no color cycling when reduce motion is on
- Remove the toolbar New Chat button on iOS (replaced by the title bar button); preserve it on macOS and visionOS
- Update `ai-features.md` to document these iOS overlay polish changes

**Out of scope:**
- Any macOS UX changes
- Any changes to the chat RAG logic, prompt assembly, or session lifecycle
- visionOS-specific changes (visionOS may receive the title bar passively but no deliberate visionOS work is in scope)

## Constraints

- **L01:** No `#available` checks for versions below macOS 26 / iOS 26.
- **L07:** The chat feature flag gates only the UI surfaces. FTS indexing must not be touched.
- **L09:** No new app-wide state manager. All new `@State` belongs in `ChatWindow` or its sub-views.
- **L16/L17:** Scribe has consulted docs; Builder must update `ai-features.md`.
- **Style:** Platform branching via `#if os(iOS)` / `#if os(macOS)`. Sub-view computed properties on view types use `UpperCamelCase`. `@Environment(\.accessibilityReduceMotion)` pattern follows the precedent in `TypingIndicator`. Use `os.Logger` — no `print()`.
- **Existing pattern:** `TypingIndicator` in `MessageBubble.swift` is the established pattern for `accessibilityReduceMotion`-aware animation; follow it for the color cycling.
- The toolbar New Chat button is currently inside a `if toolbarVisible { ... }` block; on iOS the title bar button replaces this. The `toolbarVisible` parameter must still suppress the toolbar button when `false` (Magic Assistant mode) and must not show a title bar in Magic Assistant mode either.

## Acceptance criteria

- [ ] Tapping a citation link on iOS dismisses the chat overlay/sheet
- [ ] When `conversation` is empty on iOS, centered gray placeholder text appears with "MagicChat" heading (large) and descriptive subtitle; placeholder is absent on macOS
- [ ] Placeholder disappears once the first message is sent (i.e., when `conversation` is non-empty)
- [ ] iOS overlay has a title bar with "MagicChat" centered and a New Chat button on the right, visible only when `toolbarVisible == true`
- [ ] "MagicChat" title text is `Color.takeNotePink` when idle
- [ ] While `responseIsGenerating == true`, title text cycles through pink → orange → purple → blue
- [ ] When generation completes, title returns to static `Color.takeNotePink`
- [ ] When `accessibilityReduceMotion` is true, title color does not cycle; it remains static `Color.takeNotePink`
- [ ] The existing toolbar New Chat button does not appear on iOS (replaced by the title bar button)
- [ ] On macOS the toolbar New Chat button continues to appear as before
- [ ] Mac UX is completely unaffected by all changes
- [ ] `ai-features.md` is updated to document the iOS overlay polish

## Risks / notes

- The chat is presented as a `.popover` on iOS (`showChatPopover` in `MainWindow`). Dismissing the popover from inside `ChatWindow` requires a dismiss mechanism passed in or accessed via `@Environment(\.dismiss)`. Since `ChatWindow` is already a standalone view inside the popover, `@Environment(\.dismiss)` is the correct approach — it will dismiss the containing sheet/popover. This must be wrapped in `#if os(iOS)` so it does not affect macOS.
- The `onOpenURL` handler in `MainWindow` calls `takeNoteVM.loadNoteFromURL(...)`. On iOS the deep-link URL from the `Link` inside `MessageBubble` is handled by the system and will fire `onOpenURL` in `MainWindow`. The chat sheet needs to be dismissed before or concurrently with that navigation. The approach: intercept the URL in `ChatWindow` using `.onOpenURL`, dismiss the sheet, then forward the URL to the system via `UIApplication.shared.open(_:)` — or alternatively, dismiss via a passed-in `dismissAction` closure. A simpler approach that avoids passing closures: add an `.onOpenURL` modifier inside the `#if os(iOS)` section of `ChatWindow` that calls `dismiss()` and lets the URL continue to propagate to `MainWindow`'s `onOpenURL`. Confirm the chosen approach during implementation by verifying whether SwiftUI's URL propagation allows both handlers to fire.
- Color cycling animation: the `PhaseAnimator`/`TimelineView` approach is already established in `TypingIndicator`. For color cycling, a `TimelineView(.animation)` or `withAnimation` timer approach works. A clean alternative: use a `@State private var titleColorPhase: Int` incremented by a repeating timer task started in `.onAppear` / `.task` — but a `PhaseAnimator` over color values is more idiomatic and consistent with the existing codebase pattern. Builder should choose the most idiomatic SwiftUI approach consistent with `TypingIndicator`.
