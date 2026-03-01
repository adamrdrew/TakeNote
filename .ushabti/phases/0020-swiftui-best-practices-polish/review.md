# Review: Phase 0020 — SwiftUI Best Practices & Performance Polish

## Summary

All 12 steps verified. All 13 acceptance criteria satisfied. The three manually-applied post-build fixes (`@State var noteContainer` non-private, `Self.logger` at call sites) are consistent with the phase.md rationale and code reality. No law violations. Docs are reconciled. Build confirmed clean on iOS Simulator and macOS per builder report.

## Verified

### Acceptance Criteria

1. **AC1 — Zero `foregroundColor` remaining:** `grep` returns no results for `.foregroundColor(` in any of the six listed files. Confirmed clean.

2. **AC2 — `@State`/`@FocusState` have `private`:** The only non-private `@State var` remaining is `@State var noteContainer` in `NoteContainerDetailsEditor.swift` (line 16), which is passed as an init parameter — a documented exception in both phase.md and step S002 notes. All other `@State` and `@FocusState` declarations across all touched files carry `private`. Confirmed.

3. **AC3 — `filteredNotes`/`sortedNotes` are now cached `@State`:** No computed properties named `filteredNotes` or `sortedNotes` exist anywhere in the codebase. `NoteList.swift` has `@State private var cachedFilteredNotes`, `cachedSortedNotes`, `cachedStarredNotes`, `cachedUnstarredNotes` populated by `rebuildNoteCache()`, wired to `onChange` for all five inputs (notes, noteSearchText, selectedContainer, sortBy, sortOrder) and to `.onAppear`. Confirmed.

4. **AC4 — `NoteListHeader` note count cached:** `NoteListHeader.swift` has `@State private var cachedNoteCount: Int = 0`, `rebuildNoteCount()` method, and `onChange` wiring for both `allNotes` and `takeNoteVM.selectedContainer`. No inline `allNotes.filter { ... }.count` in any computed property body. Confirmed.

5. **AC5 — Sidebar system folder sort cached:** `Sidebar.swift` has `private var sortedSystemFolders: [NoteContainer]` computed property (line 130). The `ForEach` in `body` iterates `sortedSystemFolders` (line 139), not inline `.sorted(by:)`. Confirmed.

6. **AC6 — `MessageBubble` accepts `[UUID: String]`:** `MessageBubble.swift` declares `var noteTitles: [UUID: String] = [:]` (line 50). No `[Note]` property. `ChatWindow.swift` computes `private var noteTitleMap: [UUID: String]` (lines 58-60) and passes it as `noteTitles: noteTitleMap` (line 266). SwiftData import removed from `MessageBubble`. Confirmed.

7. **AC7 — No `AnyView` in `TakeNoteImageProvider`:** `AnyView` is absent from the entire codebase. `TakeNoteImageProvider.makeImage(url:)` is annotated `@ViewBuilder` (line 15), uses `if-let` branches returning direct view expressions, and preserves `#if os(macOS)`/`#else` branching. Confirmed.

8. **AC8 — `onChange(of: selectedNotes)` delegates to named method:** `NoteList.swift` line 275: the closure body is a single call `handleNoteSelectionChange(old: oldValue, new: newValue)`. The extracted method `handleNoteSelectionChange(old:new:)` exists at line 187 with the full original logic. Confirmed.

9. **AC9 — `FolderListEntry` and `TagListEntry` use `.foregroundStyle(.primary)`:** Both files have `.foregroundStyle(.primary)` in place of the previous `colorScheme`-conditional expression. `@Environment(\.colorScheme)` is absent from both files. The remaining `colorScheme ==` in the codebase is in `NoteEditor.swift` for `CodeEditor` theme selection, which is unrelated to this step. Confirmed.

10. **AC10 — `MultiNoteViewer.body` has one `ZStack`:** `MultiNoteViewer.body` (lines 26-52) starts directly with `GeometryReader { geo in`, containing a single `ZStack` wrapping the `ForEach(PaperCard)`. No outer `ZStack` wrapper. `.frame(maxWidth: .infinity, maxHeight: .infinity)` is on the `GeometryReader`. Confirmed.

11. **AC11 — `logger` is `static let`:** `MainWindow.swift` line 29: `static let logger = Logger(...)`. `NoteEditor.swift` line 117: `static let logger = Logger(...)`. All call sites in both files use `Self.logger.` after the manual correction. Confirmed.

12. **AC12 — Compiles without errors:** Builder and user confirm successful build on iOS Simulator (iPhone 17 Pro) and macOS. Three post-build fixes applied manually and verified correct. Confirmed.

13. **AC13 — No functional behavior changes:** The phase is a pure refactor of deprecated API, access control, caching, and structural cleanup. No business logic was altered. Confirmed by scope review.

### Laws

- **L01:** Deployment targets remain macOS 26 / iOS 26 / xrOS 26. No `#available` guards below these versions introduced.
- **L02–L03:** No `@Model` changes.
- **L04–L06:** No LLM session changes.
- **L07:** FTS indexing paths untouched. Chat flag checks unchanged.
- **L08–L16:** Not touched by this phase.
- **L17:** Builder consulted and updated `views.md` as part of S012.
- **L18–L19:** Docs reconciled (see below).
- **L20:** Version bumped — `CURRENT_PROJECT_VERSION` 22 → 23, `MARKETING_VERSION` 1.1.18 → 1.1.19. All four occurrences of each updated in `TakeNote.xcodeproj/project.pbxproj`.

### Docs Reconciliation (L18/L19)

`.ushabti/docs/views.md` accurately reflects all code changes:

- **NoteList section:** Describes `rebuildNoteCache()`, all five `onChange` inputs, four cached `@State` arrays, `folderHasStarredNotes` as `!cachedStarredNotes.isEmpty`, and `handleNoteSelectionChange(old:new:)`. Matches code.
- **NoteListHeader section:** Describes `cachedNoteCount`, `rebuildNoteCount()`, and `onChange` wiring. Matches code.
- **ChatWindow/MessageBubble section:** Describes `noteTitles: [UUID: String]` interface and `noteTitleMap` pre-computation in `ChatWindow`. Matches code.
- **Sidebar section:** Describes `sortedSystemFolders` private computed property and deterministic sort order. Matches code.

### Style

- `UpperCamelCase` sub-view computed properties: unchanged and correct throughout.
- `private` `EnvironmentKey` structs: all file-local and private. Unchanged and correct.
- `os.Logger` with `static let`: now correct in `MainWindow` and `NoteEditor`.
- No `print()` introduced.

## Issues

None. The three manually-applied post-build fixes are each consistent with the phase specification:
1. `@State var noteContainer` non-private — documented exception in phase.md AC2 and step S002.
2. `Self.logger.info(...)` in `MainWindow` — correct usage of a `static let` property from an instance method.
3. `Self.logger.*` at four sites in `NoteEditor` — same rationale.

## Required follow-ups

None.

## Decision

**GREEN.**

Phase 0020 is complete. All 13 acceptance criteria satisfied, all 12 steps verified, all laws complied with, documentation reconciled, and version bumped to build 23 / 1.1.19. Weighed and found true.
