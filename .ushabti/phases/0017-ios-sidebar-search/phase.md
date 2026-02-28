# Phase 0017: iOS Sidebar Search (Apple Notes Pattern)

## Intent

Phase 0016 added `DefaultToolbarItem(kind: .search, placement: .bottomBar)` to the iOS sidebar toolbar, but this item has no effect because `.searchable()` is attached to `NoteList` in the content column — not the sidebar column. The `DefaultToolbarItem` requires a `.searchable()` in the same navigation column to wire to.

The correct fix is the Apple Notes pattern: attach `.searchable()` to the `NavigationSplitView` itself on iOS, which causes the system to render the search bar at the bottom of the sidebar when the sidebar is visible on iPhone. This requires lifting search text state into `TakeNoteVM` (L09 — TakeNoteVM is the sole app-wide state manager), so a single binding can serve both the NavigationSplitView-level searchable on iOS and the NoteList-level searchable on macOS.

When search text is active, results should be global (across all non-trash/non-buffer notes), not scoped to the currently selected folder. This matches the All Notes search path that already exists in `filteredNotes`.

## Scope

**In scope:**
- Add `noteSearchText: String = ""` property to `TakeNoteVM`
- Remove `@State var noteSearchText: String = ""` from `NoteList`
- Remove the broken `DefaultToolbarItem(kind: .search, placement: .bottomBar)` from the sidebar column toolbar in `MainWindow` (the one from Phase 0016 that cannot wire to anything)
- On iOS: attach `.searchable(text: $takeNoteVM.noteSearchText)` to the `NavigationSplitView` in `MainWindow`
- On macOS: keep `.searchable(text: $takeNoteVM.noteSearchText)` on the `List` in `NoteList` (updated binding only)
- Update `NoteList.filteredNotes` so that when `noteSearchText` is non-empty the candidate pool is all non-trash/non-buffer notes regardless of selected container (global search)
- Preserve the content column `DefaultToolbarItem(kind: .search, placement: .bottomBar)` on iOS (`MainWindow.swift` line ~202) as-is — it correctly wires to the NoteList-level searchable
- Update `ai-features.md` and `views.md` docs to reflect the changes

**Out of scope:**
- Any change to FTS indexing behavior (L07)
- Any change to macOS search behavior beyond updating the binding to point to `TakeNoteVM.noteSearchText`
- Any new SwiftData model changes
- Any change to the `SearchIndexService` or `SearchIndex` implementation

## Constraints

- L09: `TakeNoteVM` is the sole app-wide state manager. `noteSearchText` must live there, not in `NoteList`.
- L07: FTS indexing runs unconditionally. Do not add any feature-flag guard to indexing paths.
- L01: iOS 26 minimum; no `#available` guards needed for iOS 26 APIs.
- L17/L19: Docs must be updated and reconciled as part of this Phase.
- Style: New `TakeNoteVM` property uses `lowerCamelCase` — `noteSearchText`.
- There must be exactly one `.searchable()` modifier per platform. On iOS it lives on the `NavigationSplitView`; on macOS it lives on the `List` in `NoteList`. They share one state property via `TakeNoteVM`.
- Do not introduce a second search state property. The single `noteSearchText` on `TakeNoteVM` is the source of truth for both platforms.
- Platform-specific code uses `#if os(iOS)` / `#if os(macOS)` conditional compilation blocks.

## Acceptance Criteria

- [ ] On iPhone iOS, a search bar appears at the bottom of the sidebar column (Apple Notes pattern) when the sidebar is visible
- [ ] `noteSearchText: String = ""` is a property on `TakeNoteVM`
- [ ] `@State var noteSearchText` is removed from `NoteList`
- [ ] There is exactly one `.searchable()` modifier per platform — on `NavigationSplitView` for iOS, on `List` in `NoteList` for macOS
- [ ] The broken `DefaultToolbarItem(kind: .search, placement: .bottomBar)` is removed from the sidebar column toolbar
- [ ] The content column's `DefaultToolbarItem(kind: .search, placement: .bottomBar)` on iOS is preserved
- [ ] When `noteSearchText` is non-empty, `filteredNotes` searches all non-trash/non-buffer notes regardless of the selected container
- [ ] macOS search behavior is functionally unchanged
- [ ] `views.md` is updated to reflect the `.searchable()` placement change and global search behavior
- [ ] `ai-features.md` is updated to reflect the sidebar search changes (Phase 0016 section correction)

## Risks / Notes

- The content column `DefaultToolbarItem(kind: .search, placement: .bottomBar)` at line ~202 of `MainWindow.swift` wires to the NoteList `.searchable()` on iOS. After this change, on iOS the `.searchable()` moves to the NavigationSplitView level; verify that this `DefaultToolbarItem` in the content column still works or determine if it should also be removed.
- On iPhone the NavigationSplitView operates in compact mode — the sidebar, content, and detail are stacked. The `.searchable()` on the NavigationSplitView should place the search bar at the bottom of the sidebar column when navigated to the sidebar on iPhone. This is consistent with Apple Notes behavior.
- `NoteList` accesses `takeNoteVM` via `@Environment(TakeNoteVM.self)` already — the binding change is straightforward since `@Bindable var takeNoteVM = takeNoteVM` is already used in `NoteList.body`.
