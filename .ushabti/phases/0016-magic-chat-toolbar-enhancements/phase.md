# Phase 0016: Magic Chat & Toolbar Enhancements

## Intent

Three targeted UI improvements to Magic Chat and the iOS sidebar:

1. **Empty-state placeholder on Mac** — The centered gray "MagicChat" heading and subtitle placeholder added in Phase 0015 is currently guarded by `#if os(iOS)`, so it never appears on macOS. Removing that platform guard (or widening it to include macOS) will make the same placeholder visible whenever the conversation is empty on Mac.

2. **Magic Chat button on iOS sidebar** — On iOS the chat button only appears in the `NoteList` toolbar (i.e., after the user navigates into a note container). It should also appear on the root sidebar view so that users can open chat from the app's launch screen to query across all notes.

3. **Search button on iOS sidebar** — While adding the chat button to the iOS sidebar toolbar, the `DefaultToolbarItem(kind: .search)` button should also be added there, matching the pattern already used in the `NoteList` toolbar.

## Scope

**In scope:**
- Remove/widen the `#if os(iOS)` guard on `EmptyStatePlaceholder` in `ChatWindow.swift` so it renders on macOS as well.
- Add a Magic Chat toolbar button to the sidebar column toolbar in `MainWindow.swift` (iOS only, gated on `chatFeatureFlagEnabled && chatEnabled`).
- Add a search toolbar button (`DefaultToolbarItem(kind: .search)`) to the sidebar column toolbar in `MainWindow.swift` (iOS only).
- The chat popover on the sidebar reuses `showChatPopover` state already present on `MainWindow`, or a new dedicated `@State` bool; whichever is cleaner given that the sidebar and note-list chat buttons must be independently dismissible.
- Update `.ushabti/docs/ai-features.md` to reflect the extended empty-state behavior.

**Out of scope:**
- Any changes to Mac toolbar layout.
- Any changes to visionOS.
- Changes to the `NoteList` toolbar (the existing chat button there is unaffected).
- New AI features or prompt changes.
- Any changes to FTS indexing.

## Constraints

- **L07** — Any new Magic Chat toolbar button on the sidebar MUST be gated on `chatFeatureFlagEnabled`. FTS indexing must not be touched.
- **L05** — The chat availability gate (`chatEnabled`, which checks `takeNoteVM.aiIsAvailable && notes.count > 0`) must be applied consistently with the existing note-list chat button.
- **L09** — No new state managers. New `@State` booleans for popover presentation belong on `MainWindow`, which already owns `showChatPopover`.
- **L01** — No `#available` checks below macOS 26 / iOS 26.
- **Style** — Toolbar button pattern in the sidebar must follow the `ToolbarItem(placement: toolbarPlacement)` pattern used by the existing Add Folder and Add Tag buttons. Popover attachment must match the existing chat popover in `NoteListToolbar`.
- **Style** — Sub-view computed properties use `UpperCamelCase`; new `@State` booleans use the `showX` / `xIsPresented` convention.

## Acceptance criteria

- [ ] When the chat conversation is empty on macOS, the centered gray "MagicChat" heading and subtitle placeholder is visible.
- [ ] On iOS, tapping away from any selected container (root sidebar view) shows a Magic Chat button in the toolbar.
- [ ] On iOS, the root sidebar toolbar also contains a Search button.
- [ ] Tapping the sidebar Magic Chat button opens the chat overlay (same `ChatWindow` popover behavior as in the note-list toolbar).
- [ ] Tapping the sidebar Search button activates search (same `DefaultToolbarItem(kind: .search)` behavior as in the note-list toolbar).
- [ ] The sidebar Magic Chat button is hidden when `chatFeatureFlagEnabled` is `false` or `chatEnabled` is `false` (no notes or AI unavailable).
- [ ] The existing `NoteList` toolbar is unaffected.
- [ ] Mac and visionOS layout are unaffected.
- [ ] `.ushabti/docs/ai-features.md` is updated to reflect the widened empty-state placeholder.

## Risks / notes

- `MainWindow` already has `@State var showChatPopover: Bool` used by the note-list chat button. The sidebar chat button needs its own independent presentation boolean (e.g., `showSidebarChatPopover`) so both popovers can be independently dismissed without conflicting state.
- `DefaultToolbarItem(kind: .search)` is a SwiftUI built-in that wires to the navigation search field automatically; no manual state is required for the search button.
- The `EmptyStatePlaceholder` computed property is currently defined inside `#if os(iOS)`. On macOS `ChatWindow` is hosted in a separate `Window` scene (not a popover), so the placeholder will appear in that window when conversation is empty — this is the correct and desired behavior.
- On iOS the `ChatWindow` is used both as a standalone note-list popover and (after this Phase) as a sidebar popover. Both share the same `ChatWindow()` initializer with all defaults, which is correct since both target the full note corpus.
