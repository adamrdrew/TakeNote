# Review: Phase 0017 — iOS Sidebar Search (Apple Notes Pattern)

## Summary

All six steps verified. Code is correct, complete, and compliant with all laws and style rules. Build confirmed by user (iOS and macOS). Version bumped to 20 / 1.1.16 as required by L20.

## Verified

### S001 — Add noteSearchText to TakeNoteVM

`TakeNoteVM.swift` line 50: `var noteSearchText: String = ""` present in the UI State section, after `showMultiNoteView`. Correct placement, correct naming (lowerCamelCase, per style), correct initialization. L09 satisfied — single source of truth in TakeNoteVM.

### S002 — Update NoteList to use TakeNoteVM.noteSearchText

`NoteList.swift`: No `@State var noteSearchText` present. All three references to search text in `filteredNotes` use `takeNoteVM.noteSearchText`. The `.searchable(text: $takeNoteVM.noteSearchText)` modifier on the `List` is wrapped in `#if os(macOS)` / `#endif` at lines 255–257. Uses `@Bindable var takeNoteVM = takeNoteVM` already declared in `body`.

### S003 — Move .searchable() to NavigationSplitView on iOS / remove broken sidebar DefaultToolbarItem

`MainWindow.swift` lines 178–193: The sidebar column iOS toolbar contains only the Magic Chat button (gated on `chatFeatureFlagEnabled && chatEnabled`). The `DefaultToolbarItem(kind: .search)` from Phase 0016 is gone. No `DefaultToolbarItem` exists anywhere in the codebase.

Lines 217–219: `#if os(iOS) .searchable(text: $takeNoteVM.noteSearchText) #endif` is attached to the `NavigationSplitView` — correct Apple Notes pattern placement.

**Content column search item:** The acceptance criterion said "preserve the content column `DefaultToolbarItem(kind: .search)` on iOS." The steps.md granted Builder explicit discretion to remove it if doing so would produce a duplicate search button (since search is now at `NavigationSplitView` level). Builder removed it and documented the decision. The phase.md Risks/Notes section itself anticipated this outcome ("determine if it should also be removed"). The implementation is architecturally correct: `DefaultToolbarItem(kind: .search)` in the content column on iOS after this change would produce a redundant UI element wiring to the same `NavigationSplitView`-level searchable. The Builder's judgment is sound and within the delegated scope of steps.md.

### S004 — Update filteredNotes for global search behavior

`NoteList.swift` lines 72–90: `filteredNotes` refactored correctly.
1. `allNotesSource` = notes excluding trash and buffer.
2. `if !takeNoteVM.noteSearchText.isEmpty` → FTS search against `allNotesSource` (global), BM25-ranked via `indexMap`.
3. `if takeNoteVM.selectedContainer?.isAllNotes == true` → returns `allNotesSource`.
4. Else → returns `selectedContainer?.notes ?? []`.

Matches the required structure from steps.md exactly. BM25 ranking via `indexMap` sort preserved within `filteredNotes`. Note: `sortedNotes` re-sorts `filteredNotes` by date — this was identical pre-Phase behavior and is not a regression.

### S005 — Update views.md

`views.md` updated accurately:
- NoteList section: `noteSearchText` lives in TakeNoteVM, global search behavior when non-empty, platform-specific `.searchable()` placement documented.
- MainWindow section: iOS `.searchable()` on `NavigationSplitView` documented.
- Multi-Platform Adaptations section: search bar placement difference noted with full detail.

All changes accurate against code.

### S006 — Update ai-features.md

`ai-features.md` updated accurately:
- Phase 0016 Search Button subsection retitled "Phase 0016 — non-functional; replaced in Phase 0017."
- Documents that `DefaultToolbarItem(kind: .search)` was non-functional (no `.searchable()` in sidebar column to wire to).
- Documents Phase 0017 fix: removal of broken item, `.searchable()` moved to `NavigationSplitView`, `noteSearchText` moved to `TakeNoteVM`, global search when non-empty.

All changes accurate against code.

## Laws Verification

- **L01:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `MACOSX_DEPLOYMENT_TARGET = 26.0` confirmed. No `#available` checks introduced.
- **L07:** No `chatFeatureFlagEnabled` guard added to any FTS indexing path. The `.searchable()` placement is a UI concern only; `SearchIndexService` is untouched.
- **L09:** `noteSearchText` lives in `TakeNoteVM`. No new state managers introduced.
- **L17/L18/L19:** Both `views.md` and `ai-features.md` updated and reconciled with all code changes.
- **L20:** Bumped `CURRENT_PROJECT_VERSION` from 19 to 20 and `MARKETING_VERSION` from 1.1.15 to 1.1.16 across all four entries in `project.pbxproj`.

All other laws: no SwiftData model changes, no LLM calls, no CommandRegistry changes, no widget code changes. No violations detected.

## Style Verification

- `noteSearchText` is `lowerCamelCase` — correct.
- Platform branching uses `#if os(iOS)` / `#if os(macOS)` — correct.
- No `print()` introduced; no new service objects.
- `@Bindable var takeNoteVM = takeNoteVM` pattern correctly used in both `NoteList.body` and `MainWindow.body`.

## Issues

None blocking. The acceptance criterion about "preserving" the content column `DefaultToolbarItem` was superseded by reasoned discretion in steps.md, with phase.md itself anticipating removal as the likely outcome. The decision is documented and architecturally sound.

## Decision

GREEN. Phase 0017 is complete. The iOS sidebar now receives a `.searchable()` at the `NavigationSplitView` level following the Apple Notes pattern. Search state is unified in `TakeNoteVM`. Global search is active when search text is non-empty. Docs are reconciled. Build version is 20 / 1.1.16.

Weighed and found true.
