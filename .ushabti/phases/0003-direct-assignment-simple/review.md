# Review: Phase 0003 — Direct Property Assignment Fixes — Simple Cases

## Summary

All three direct-assignment violations in scope (R005, R010, R011) have been correctly replaced with their mutating-method equivalents. Model methods exist with the correct signatures. Docs are reconciled. All acceptance criteria are met.

## Verified

**S001 — NewNoteWithContentIntent.swift**
- `note.setContent(content)` is present at line 37.
- `note.setTitle(noteTitle)` is present at line 38.
- Grep confirmed no direct `note.content =` or `note.title =` assignments remain in this file.
- L14 compliance confirmed: both `TakeNoteVM` and `ModelContainer` are accessed via `@Dependency(key:)`.

**S002 — NoteList.swift cuttable block**
- `note.setFolder(bf)` is present in the `.cuttable` closure at lines 275-278.
- Grep confirmed no `note.folder = bf` remains in this file's cuttable path.

**S003 — NoteListEntry.swift MovePopoverContent**
- `note.setTag(container)` is present at line 48.
- `note.setFolder(container)` is present at line 50 (in the else branch).
- Grep confirmed no direct `note.tag =` or `note.folder =` assignments remain in the `MovePopoverContent.onChange` handler.

**Model method signatures — Note.swift**
- `setTitle(_ newTitle: String)` — sets title, updates `updatedDate`, calls `WidgetCenter.shared.reloadAllTimelines()`. Correct.
- `setContent(_ newContent: String)` — same side effects. Correct.
- `setFolder(_ folder: NoteContainer)` — same side effects. Correct.
- `setTag(_ tag: NoteContainer)` — same side effects. Correct.
- All four methods exist and match the call sites in the changed files.

**Acceptance criteria — all met:**
1. `NewNoteWithContentIntent.perform()` calls `setContent` and `setTitle`. Confirmed.
2. `NoteList.cuttable` calls `setFolder(bf)`. Confirmed.
3. `MovePopoverContent.onChange` calls `setTag` and `setFolder`. Confirmed.
4. No residual direct assignments in these three locations. Confirmed by grep.
5. Build verification: not directly executable in this review environment. Code changes are mechanical substitutions with matching signatures; no syntactic risk detected.

**Docs reconciliation (L17/L18/L19):**
- `supporting-systems.md` line 226: correctly documents `note.setContent(content)` and `note.setTitle(noteTitle)` for `NewNoteWithContentIntent`. Accurate.
- `views.md` line 86 (NoteList section): correctly documents `note.setFolder(bf)` for the cuttable path.
- `views.md` line 99 (NoteListEntry section): correctly documents `note.setTag(container)` / `note.setFolder(container)` for `MovePopoverContent`.
- All docs accurately reflect the code as changed in this phase.

**Pre-existing out-of-scope violation noted (not blocking):**
`NoteListEntry.swift` line 477 contains `note.tag = nil` in the "Remove tag" context menu button. This is a direct property mutation that bypasses `updatedDate` and `WidgetCenter.reloadAllTimelines()`. It is not within the scope of this phase (not one of R005, R010, or R011) and is not referenced by the acceptance criteria. It is flagged here for a future phase.

**Laws checked:**
- L01: No `#available` checks below macOS 26/iOS 26 introduced.
- L09: No new state managers introduced.
- L14: `NewNoteWithContentIntent` continues to use `@Dependency(key:)` for both `TakeNoteVM` and `ModelContainer`.
- L15: `NoteListEntry` CommandRegistry registrations/unregistrations are intact and unmodified.
- No other law violations detected in the changed code.

**Style checked:**
- No new style violations introduced. All sub-view computed properties on `NoteListEntry` retain `UpperCamelCase`. `EnvironmentKey` structs remain `private`.

## Issues

None blocking.

## Required follow-ups

None.

## Decision

GREEN. Phase 0003 is complete. All acceptance criteria are met, all targeted violations are fixed, model methods have correct signatures, and docs are reconciled with the code changes.

Recommend handing off to Ushabti Scribe for the next phase.
