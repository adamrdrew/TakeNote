# Steps

## S001: Add dismiss-on-citation-link-tap (iOS only)

**Intent:** When the user taps a citation link in the chat overlay on iOS, the overlay should dismiss so the user can see the note being navigated to.

**Work:**
- In `ChatWindow.swift`, add `@Environment(\.dismiss) private var dismiss` inside an `#if os(iOS)` conditional block (or unconditionally, since `dismiss` is available on all platforms but only called on iOS).
- Add an `.onOpenURL` modifier inside the `#if os(iOS)` section of `ChatWindow`'s `body` that calls `dismiss()` when a `takenote://` URL is received. The URL continues to propagate to `MainWindow`'s `onOpenURL` handler, which performs the actual navigation.
- Confirm during implementation that SwiftUI URL propagation allows both the `ChatWindow` and `MainWindow` `onOpenURL` handlers to fire (they should, as propagation is not stopped by default). If propagation stops after the first handler, call `UIApplication.shared.open(url)` explicitly after `dismiss()`.
- Wrap all iOS-specific code in `#if os(iOS)`.

**Done when:** Tapping a citation link in the iOS chat overlay dismisses the overlay and navigates to the referenced note.

---

## S002: Add empty-state placeholder (iOS only)

**Intent:** Show a centered, styled placeholder when the conversation is empty on iOS, giving the chat a polished initial appearance.

**Work:**
- In `ChatWindow.swift`, add an iOS-only computed sub-view property `EmptyStatePlaceholder: some View` following the `UpperCamelCase` sub-view convention.
- The placeholder contains a `VStack` with:
  - A `Text("MagicChat")` in a fairly large font (e.g., `.title` or `.title2`), bold.
  - A `Text("Chat with your notes using natural language and on-device, private AI.")` in `.subheadline` or similar, multiline, centered.
  - Both texts use `.foregroundStyle(.secondary)` (gray).
- Center the placeholder both horizontally and vertically using `Spacer()` above and below inside the scroll area, or by wrapping in a `frame(maxWidth: .infinity, maxHeight: .infinity)` with `.center` alignment.
- Conditioned on `conversation.isEmpty`, shown in place of (or layered over) the empty scroll view on iOS only, using `#if os(iOS)`.
- Disappears once `conversation` is non-empty (no explicit action needed; SwiftUI reactivity handles this).

**Done when:** On iOS, launching the chat overlay shows the centered gray placeholder; sending the first message causes it to disappear.

---

## S003: Add iOS title bar to ChatWindow

**Intent:** Give the iOS chat overlay a custom title bar with centered "MagicChat" text and a New Chat button on the right, matching standard iOS sheet/overlay conventions.

**Work:**
- In `ChatWindow.swift`, add an iOS-only computed sub-view property `TitleBar: some View`.
- The title bar is an `HStack` or `ZStack` that produces:
  - "MagicChat" text centered horizontally. Use `ZStack` with the text in the center and the button positioned to the trailing side to achieve true centering of the text label.
  - A New Chat button (`Image(systemName: "plus.message")` or `Label`) on the right side.
  - Appropriate vertical padding and a `Divider()` below.
- The "MagicChat" text color is `Color.takeNotePink` (static, pending S004 which animates it). Use a `@State private var magicChatTitleColor: Color = .takeNotePink` that S004 will animate.
- The New Chat button calls the existing `newChat()` method.
- The title bar is only shown on iOS and only when `toolbarVisible == true`.
- Insert `TitleBar` at the top of the `VStack` in `body`, wrapped in `#if os(iOS)`.

**Done when:** The iOS chat overlay displays a title bar with "MagicChat" centered and a New Chat button on the right. macOS is unaffected.

---

## S004: Animate title color during generation (iOS only)

**Intent:** Provide visual feedback during response generation by cycling the "MagicChat" title text through colors, respecting reduce motion.

**Work:**
- In `ChatWindow.swift`, add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` (iOS only, or unconditionally — it is available on all platforms).
- Add `@State private var titleColorPhase: Int = 0` (iOS only).
- Define the color cycle array as a file-scope or computed constant: `[Color.takeNotePink, .orange, .purple, .blue]`.
- Implement animation using a `.task(id: responseIsGenerating)` or `.onChange(of: responseIsGenerating)` approach:
  - When `responseIsGenerating` becomes `true` and `reduceMotion` is `false`: start a repeating async loop (using `Task { while responseIsGenerating { ... await Task.sleep(...); titleColorPhase = (titleColorPhase + 1) % 4 } }`) to cycle `titleColorPhase`.
  - When `responseIsGenerating` becomes `false`: reset `titleColorPhase` to 0 (pink).
  - When `reduceMotion` is `true`: do not start the loop; title remains static pink.
- In `TitleBar`, replace the static `Color.takeNotePink` on the "MagicChat" text with a computed color: `responseIsGenerating && !reduceMotion ? titleColors[titleColorPhase] : Color.takeNotePink`. Apply `.animation(.easeInOut(duration: 0.4), value: titleColorPhase)` to the text.
- All animation state (`titleColorPhase`, the Task) is iOS-only and scoped to `#if os(iOS)` blocks.

**Done when:** During generation on iOS, the "MagicChat" title cycles through pink, orange, purple, blue smoothly. When idle or reduce motion is on, it shows static pink. macOS is unaffected.

---

## S005: Remove iOS toolbar New Chat button

**Intent:** The New Chat button now lives in the iOS title bar (S003), so the toolbar button must not appear on iOS to avoid duplication.

**Work:**
- In `ChatWindow.swift`, locate the `.toolbar` modifier containing the `if toolbarVisible { ... }` block.
- Wrap the toolbar `ToolbarItem` content in `#if os(macOS)` (and `#if os(visionOS)` if needed) so it only renders on non-iOS platforms.
- Verify that `toolbarVisible == false` (Magic Assistant mode) still works: since `toolbarVisible` suppresses the title bar too (from S003), no button appears in either location when `toolbarVisible` is false on iOS.
- On macOS, behavior is unchanged: toolbar New Chat button appears when `toolbarVisible == true`.

**Done when:** On iOS, only the title bar New Chat button appears (no duplicate toolbar button). On macOS, the toolbar button remains.

---

## S006: Update ai-features.md

**Intent:** Keep project documentation current with the implemented iOS overlay polish, satisfying L17 and L19.

**Work:**
- In `.ushabti/docs/ai-features.md`, add a new subsection under the Magic Chat section titled "### iOS Overlay Polish (Phase 0015)".
- Document:
  - The dismiss-on-citation-link behavior and the `onOpenURL` + `dismiss()` mechanism used.
  - The empty-state placeholder: when it shows, what it contains, that it is iOS-only.
  - The iOS title bar: structure (`ZStack` centering, New Chat button placement), `toolbarVisible` gating, that macOS toolbar button is preserved.
  - The animated title color cycling: the color sequence, `responseIsGenerating` lifecycle, `accessibilityReduceMotion` respect, and how it is implemented (`titleColorPhase` state + Task loop or chosen equivalent).
  - A note that all changes are iOS-only and macOS is unaffected.

**Done when:** `ai-features.md` accurately documents all four iOS overlay polish features introduced in this phase.
