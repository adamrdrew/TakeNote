# Steps

## S001: Add dedicated sidebar chat popover state to MainWindow

**Intent:** Provide an independent presentation boolean for the sidebar chat popover so it does not conflict with the existing `showChatPopover` used by the note-list chat button.

**Work:**
- In `MainWindow.swift`, add `@State var showSidebarChatPopover: Bool = false` alongside the existing `showChatPopover` state.
- Add a corresponding action method `func doShowSidebarChatPopover()` following the same pattern as `doShowChatPopover()`.

**Done when:** `MainWindow` compiles with the new state property and action method present; existing behavior is unchanged.

## S002: Add Magic Chat and Search buttons to the iOS sidebar toolbar

**Intent:** Give iOS users access to Magic Chat and search from the root sidebar view, which is the first screen they see on launch.

**Work:**
- In `MainWindow.swift`, locate the `Sidebar()` toolbar block (the one containing Add Folder and Add Tag buttons).
- Inside that toolbar block, add an `#if os(iOS)` conditional compilation block containing:
  - A `DefaultToolbarItem(kind: .search, placement: .bottomBar)` — matching the pattern already used in the `NoteList` toolbar.
  - A `ToolbarItem(placement: toolbarPlacement)` that renders the chat button only when `chatFeatureFlagEnabled && chatEnabled` is true. The button action calls `doShowSidebarChatPopover()`. The button label uses `Label("Chat", systemImage: "message")` and a `.help("AI Chat")` modifier. Attach the `ChatWindow()` popover via `.popover(isPresented: $showSidebarChatPopover, arrowEdge: .trailing)` on this button — matching the pattern used in `NoteListToolbar`.

**Done when:** On an iOS device/simulator, the sidebar toolbar contains a search button and (when chat is enabled) a chat button. Tapping the chat button opens a `ChatWindow` popover. Tapping the search button activates search.

## S003: Widen the EmptyStatePlaceholder guard in ChatWindow

**Intent:** Show the empty-state placeholder on macOS when the conversation is empty, mirroring the existing iOS behavior.

**Work:**
- In `ChatWindow.swift`, locate the `EmptyStatePlaceholder` computed property. It is currently defined inside `#if os(iOS)`.
- Move `EmptyStatePlaceholder` out of the `#if os(iOS)` block so it compiles on all platforms. The property body requires no changes.
- Locate the `.overlay { if conversation.isEmpty { EmptyStatePlaceholder } }` modifier applied to the `ScrollView`. It is currently inside `#if os(iOS)`.
- Remove the `#if os(iOS)` guard from that overlay modifier so it applies on macOS as well.
- Verify the `// iOS Sub-Views` MARK comment is updated to `// Sub-Views` (or `// Shared Sub-Views`) to reflect that `EmptyStatePlaceholder` is now cross-platform, while `TitleBar` remains iOS-only.

**Done when:** Running the app on macOS and opening the chat window shows the centered gray "MagicChat" heading and subtitle when no messages have been sent. iOS behavior is unchanged.

## S004: Update ai-features.md documentation

**Intent:** Keep the docs accurate regarding which platforms show the empty-state placeholder, per L17/L18/L19.

**Work:**
- In `.ushabti/docs/ai-features.md`, locate the "Empty-State Placeholder" subsection under "iOS Overlay Polish (Phase 0015)".
- Update the description to note that after Phase 0016 the placeholder is cross-platform (macOS and iOS), no longer iOS-only.
- Update or remove the "iOS only; no placeholder is shown on macOS." sentence.
- Note the Phase 0016 context where appropriate (e.g., add a "Phase 0016 changes" note or update the existing bullet to reflect the widened guard).
- Also add a note in the iOS Overlay Polish section (or a new Phase 0016 section) documenting the new sidebar toolbar buttons: Magic Chat and Search on the iOS sidebar.

**Done when:** `ai-features.md` accurately describes the cross-platform empty-state behavior and the new iOS sidebar toolbar buttons, with no stale "iOS only" claim for the placeholder.
