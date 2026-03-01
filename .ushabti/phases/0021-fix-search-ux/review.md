# Review: Phase 0021 — Fix Search UX — Auto-Navigate and Clear on Folder Switch

## Summary

All four steps verified. All seven acceptance criteria satisfied. No law violations. Docs reconciled. Version bumped to build 24 / 1.1.20.

## Verified

### Acceptance Criteria

1. **AC1 — Search submit navigates to All Notes:** `MainWindow.swift` lines 222-226: `.onSubmit(of: .search)` sets `takeNoteVM.isSearchNavigating = true` then `takeNoteVM.selectedContainer = takeNoteVM.allNotesFolder`. Navigation is programmatic and immediate. Satisfied.

2. **AC2 — Search text retained after submit:** The `.onSubmit` handler does not clear `noteSearchText`. The `onChange(of: selectedContainer)` handler in `NoteList.swift` lines 341-348 detects `isSearchNavigating == true` and resets only the flag (not the text). Search text is preserved. Satisfied.

3. **AC3 — Manual folder switch clears search text:** When `isSearchNavigating` is `false` (the default for all user-initiated switches), `takeNoteVM.noteSearchText = ""` is executed in the `onChange` handler. The clear fires before `rebuildNoteCache()`, so the new folder's contents are immediately displayed without stale search filtering. Satisfied.

4. **AC4 — Empty search field produces no navigation:** `guard !takeNoteVM.noteSearchText.isEmpty else { return }` (line 223) short-circuits the `.onSubmit` handler when the field is empty. Satisfied.

5. **AC5 — Flag never left true after a cycle:** The `onChange(of: selectedContainer)` handler unconditionally enters one of two mutually exclusive branches. If `isSearchNavigating` is `true`, the first branch sets it to `false`. There is no code path that sets it to `true` and then exits without the handler firing. The flag cannot persist across cycles. Satisfied.

6. **AC6 — Existing search behavior unchanged:** `rebuildNoteCache()` in `NoteList.swift` is unmodified. The global-scope search logic (searching across all non-trash/non-buffer/non-archive notes when `noteSearchText` is non-empty), FTS ranking order, sort/filter behavior, and starred-note section splitting are all unchanged. Satisfied.

7. **AC7 — Docs updated:**
   - `view-model.md`: Row for `isSearchNavigating` added to the UI State table (line 70), with accurate description of the coordination semantics and reset responsibility.
   - `views.md`: MainWindow section updated (lines 17-18) to describe `.onSubmit(of: .search)` behavior and the coordination flag. NoteList section updated (line 87) to document the conditional-clear logic in `onChange(of: selectedContainer)`. Multi-Platform Adaptations section updated (lines 278-279) to describe the end-to-end search UX behavior on both platforms.
   - Satisfied.

### Steps

- **S001:** `isSearchNavigating: Bool = false` added to `TakeNoteVM.swift` at line 55, in the UI State property block alongside `noteSearchText`. Inline comment explains the coordination purpose. Done-when satisfied.
- **S002:** `.onSubmit(of: .search)` added to `MainWindow.swift` lines 222-226, immediately after `.searchable(text:)`. Guards on non-empty text, sets flag, sets container. Done-when satisfied.
- **S003:** `onChange(of: takeNoteVM.selectedContainer)` in `NoteList.swift` lines 341-348 replaced with the conditional block. Flag checked first, reset if true; otherwise `noteSearchText` cleared. `rebuildNoteCache()` always called after. Done-when satisfied.
- **S004:** Both docs files updated as specified. Done-when satisfied.

### Laws

- **L01:** No `#available` guard for a version below iOS 26 / macOS 26 introduced by this phase. The pre-existing `if #available(iOS 26.0, *)` guard at `MainWindow.swift` line 159 was introduced in a prior commit and is redundant (iOS 26 is the minimum target) but is not a violation by the law's letter, which prohibits checks "for a version below macOS 26 / iOS 26."
- **L02-L03:** No `@Model` changes. No schema changes.
- **L04-L06:** No LLM session changes.
- **L07:** FTS indexing paths untouched. No `chatFeatureFlagEnabled` guard added to any indexing path.
- **L08-L12:** Not touched by this phase.
- **L13:** `SearchIndexService.index` type unchanged.
- **L14-L16:** Not touched by this phase.
- **L17:** Builder consulted and updated both docs files per step S004.
- **L18-L19:** Docs reconciled. Both `view-model.md` and `views.md` accurately reflect all code changes made in this phase.
- **L20:** Version bumped — `CURRENT_PROJECT_VERSION` 23 to 24, `MARKETING_VERSION` 1.1.19 to 1.1.20. All four occurrences of each field updated in `TakeNote.xcodeproj/project.pbxproj`.
- **L09:** `isSearchNavigating` added to `TakeNoteVM`, the sole app-wide state manager. Correct placement. No parallel state manager introduced.

### Style

- `lowerCamelCase` for `isSearchNavigating`: correct.
- `var isSearchNavigating: Bool = false`: follows the boolean property style of the adjacent UI State block.
- No new `EnvironmentKey` or `CommandRegistry` registrations involved; not applicable.
- No `print()` introduced.

### Docs Reconciliation

Both `.ushabti/docs/view-model.md` and `.ushabti/docs/views.md` are accurate and consistent with the implemented code. The `isSearchNavigating` row in `view-model.md` correctly describes the flag's coordination role and reset responsibility. The `views.md` updates in the MainWindow, NoteList, and Multi-Platform sections accurately describe the new behaviors.

Note for future phases: `noteSearchText` is absent from the `view-model.md` UI State table — a pre-existing gap, not introduced by this phase, and outside this phase's scope.

## Issues

None.

## Required follow-ups

None.

## Decision

**GREEN.**

Phase 0021 is complete. All seven acceptance criteria satisfied, all four steps verified, all laws complied with, documentation reconciled, and version bumped to build 24 / 1.1.20. The coordination mechanism is clean: `isSearchNavigating` is set, consumed, and reset in a single container-change cycle with no residual state.
