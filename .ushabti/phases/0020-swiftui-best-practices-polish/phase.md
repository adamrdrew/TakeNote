# Phase 0020: SwiftUI Best Practices & Performance Polish

## Intent

The codebase carries a set of accumulated SwiftUI anti-patterns identified during a comprehensive code review: deprecated API usage (`foregroundColor`), `@State` properties missing the required `private` modifier, computed properties doing expensive work on every `body` evaluation, unnecessary type-erasure via `AnyView`, inline `onChange` logic that is difficult to reason about, and manual `colorScheme` adaptation that `.foregroundStyle(.primary)` handles automatically. This phase addresses all of these in priority order — deprecated APIs first, correctness fixes second, performance improvements third, structural clean-ups last — without introducing any behavioral or feature changes.

## Scope

**In scope:**
- Replace all `foregroundColor()` with `foregroundStyle()` across six view files
- Add `private` to all `@State var` and `@FocusState var` declarations that are missing it
- Cache `NoteList.filteredNotes` and `sortedNotes` as `@State` updated by `onChange`, rather than recomputing on every `body` evaluation; pre-split starred and unstarred arrays
- Cache Sidebar system folder sort inline in ForEach by computing sorted result once per `systemFolders` change
- Replace the `allNotes.filter { ... }.count` inline computation in `NoteListHeader.noteCount` with a cached count updated via `onChange`
- Replace `allNotes: [Note]` in `ChatWindow → MessageBubble` with a `[UUID: String]` note-title dictionary to prevent full-list re-renders on any note change
- Replace `AnyView` type erasure in `TakeNoteImageProvider.makeImage(url:)` with a `@ViewBuilder` function
- Extract the inline `onChange(of: takeNoteVM.selectedNotes)` body in `NoteList.swift` into a named method `handleNoteSelectionChange(old:new:)`
- Replace `foregroundColor(colorScheme == .light ? Color.primary : Color.white)` with `.foregroundStyle(.primary)` in `FolderListEntry` and `TagListEntry`; remove the now-unused `@Environment(\.colorScheme)` injection where it becomes unused
- Remove the redundant outer `ZStack` in `MultiNoteViewer` that wraps a single inner `ZStack`
- Change `let logger` to `static let logger` on `MainWindow` and `NoteEditor`

**Out of scope:**
- Any feature additions or behavioral changes
- Accessibility improvements beyond what is directly caused by the above fixes
- Refactoring files not listed above
- Changes to data models, persistence, or LLM features

## Constraints

- **L01:** No `#available` checks for versions below macOS 26 / iOS 26. All edited files already target macOS 26/iOS 26; do not introduce version guards.
- **L09:** `TakeNoteVM` remains the single state manager. The caching strategy for `NoteList` must not introduce new `@Observable` classes; use `@State` arrays cached via `onChange`.
- **Style — `@State` ownership:** All `@State` and `@FocusState` vars must be `private`. This is the entire purpose of Step 2.
- **Style — sub-view computed properties:** Sub-view computed `var` properties on list entry types use `UpperCamelCase`. Do not rename any existing sub-view properties.
- **Style — `EnvironmentKey` structs are `private` and file-local.** No change needed here; this step does not touch keys.
- **Style — no `print()` in new code.** No new logging statements are added; existing `os.Logger` usage is being upgraded to `static let`.
- **MarkdownUI `ImageProvider` protocol:** `makeImage(url:)` has the return type `some View`. A `@ViewBuilder` function returning `some View` satisfies this constraint; `AnyView` is not required.
- **No public API or data model changes.** `MessageBubble` accepting `[UUID: String]` instead of `[Note]` changes its initializer; ensure `ChatWindow` is updated to pass the pre-computed dictionary.

## Acceptance criteria

1. Zero occurrences of `.foregroundColor(` remain in `NoteListEntry.swift`, `NoteListHeader.swift`, `FolderListEntry.swift`, `TagListEntry.swift`, `MessageBubble.swift`, and `ContextBubble.swift`.
2. Every `@State var` and `@FocusState var` in the listed files has the `private` modifier. (`NoteContainerDetailsEditor.swift` line 16 `@State var noteContainer` is a `@Binding`-adjacent initialization pattern and may retain non-private if it is an argument; confirm intent during implementation.)
3. `NoteList.filteredNotes` and `NoteList.sortedNotes` are no longer computed properties on every `body` call; they are `@State` arrays updated via `onChange` of the relevant inputs.
4. `NoteListHeader` computes note count from a cached `@State` integer updated via `onChange`, not inline in a computed property.
5. `Sidebar` body no longer calls `.sorted(by:)` inline in `ForEach`; system folders are sorted in a cached computed property or `@State` updated via `onChange`.
6. `MessageBubble` accepts `noteTitles: [UUID: String]` instead of `notes: [Note]`. `ChatWindow` passes a pre-computed dictionary.
7. `TakeNoteImageProvider.makeImage(url:)` uses no `AnyView`; it uses a `@ViewBuilder` function.
8. The `onChange(of: takeNoteVM.selectedNotes)` handler in `NoteList.swift` delegates to a named method `handleNoteSelectionChange(old:new:)`.
9. `FolderListEntry` and `TagListEntry` use `.foregroundStyle(.primary)` in place of the manual `colorScheme` conditional. The `@Environment(\.colorScheme)` property is removed from each file if it is no longer referenced.
10. `MultiNoteViewer.body` contains one `ZStack` wrapping `GeometryReader`, not an outer `ZStack` wrapping an inner `ZStack` (the `PaperCard` inner `ZStack` is unaffected).
11. `MainWindow.logger` and `NoteEditor.logger` are declared `static let`, not `let`.
12. The app compiles without errors or warnings introduced by this phase.
13. No functional behavior changes: note filtering, search, sorting, chat, image rendering, and folder display all work as before.

## Risks / notes

- Caching `filteredNotes` / `sortedNotes` requires identifying all the inputs that can change the computed result: `notes` (the `@Query` array), `takeNoteVM.noteSearchText`, `takeNoteVM.selectedContainer`, `takeNoteVM.sortBy`, `takeNoteVM.sortOrder`. All five must trigger cache invalidation. Missing one would cause stale list display.
- `NoteContainerDetailsEditor` line 16 declares `@State var noteContainer: NoteContainer`. Since `NoteContainer` is a SwiftData `@Model`, marking this `private` is safe — it is not a `@Binding`. It should be marked `private`.
- The `MessageBubble` interface change is the only change that affects a caller (`ChatWindow`). Verify that the `allNotes` `@Query` in `ChatWindow` can be converted to a dictionary at the `ChatWindow` body level without introducing a performance regression (SwiftData `@Query` arrays are already live; building a `Dictionary(uniqueKeysWithValues:)` from them is O(n) and acceptable).
- `TakeNoteImageProvider.makeImage` uses platform-conditional compilation (`#if os(macOS)`). The `@ViewBuilder` replacement must preserve the same `#if os(macOS)` / `#else` branching.
