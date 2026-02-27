# Review: Phase 0004 — Direct Property Assignment Fixes — Complex Cases

## Summary

All five steps are implemented correctly. The phase correctly resolves the two complex direct-assignment violations (R007 and R009) by applying `setContent()` where appropriate and documenting with clear rationale the two intentional design decisions to keep direct assignment.

## Verified

**S001 — Lifecycle analysis**
The notes in progress.yaml accurately reflect the code. Confirmed by direct reading:
- `NoteList.onChange` on deselection calls `note.setTitle()` (no-arg) when `note.contentHasChanged()` is true; `setTitle()` calls `setTitle(_ newTitle:)` which calls `WidgetCenter.shared.reloadAllTimelines()`.
- `Note.init(folder:)` calls `reloadAllTimelines()` once.
- The deselection path confirms the CodeEditor binding policy is sound.

**S002 — doMagicFormat() fix**
`NoteEditor.swift` line 160: `openNote!.setContent(result.formattedText)`. The old direct assignment is gone. Side effects (`updatedDate`, widget reload) now fire correctly on this deliberate one-shot mutation.

**S003 — CodeEditor binding policy**
`NoteEditor.swift` lines 233–237: direct assignment is kept; a 3-line comment immediately above the assignment explains the rationale (avoid per-keystroke `reloadAllTimelines()`; deselection path handles widget reload). Comment is accurate and matches actual code behavior. No behavioral change made.

**S004 — pasteNote() direct assignment**
`NoteList.swift` lines 146–148: direct assignment on the new uninserted `Note` object is kept; a 3-line comment explains that `Note.init(folder:)` already fired `reloadAllTimelines()` and using `setTitle()`/`setContent()` would fire redundant reloads. Comment is accurate and matches actual code behavior. No behavioral change made.

**S005 — views.md update**
The "Known Issue: Direct Content Mutation (R007)" block is gone. The NoteEditor section now contains a "Content mutation patterns" subsection describing both behaviors accurately. The NoteList section describes the pasteNote copy-paste pattern with the rationale for direct assignment. Docs are reconciled with code changes (L17/L18/L19 satisfied).

**Laws checked**
- L01: No deployment target changes.
- L02/L03: No new `@Model` types or schema changes; `ckBootstrapVersionCurrent` correctly not bumped.
- L08: No widget code touched.
- L12: `Note.uuid` is not reassigned in `pasteNote()`. The copy branch creates a fresh `Note(folder:nc)` which generates a new UUID in `init` — correct behavior for a new note.
- L17/L18/L19: Docs reconciled.

**Style guide**
The two intentional deviations from "mutations go through model methods" are explicitly documented in code comments and in docs, which is the appropriate handling for justified design exceptions.

**Comment accuracy**
The CodeEditor binding comment states widget reload "happens on note deselection in NoteList.onChange instead." This is accurate for the primary use case: `setTitle()` (no-arg) fires `reloadAllTimelines()` when `contentHasChanged()` is true — which it will be after any keystroke since `contentHash` is only updated by `generateSummary()`. The edge case where a renamed note's `setTitle()` no-arg returns early (title != defaultTitle) is a known subtlety that does not undermine the documented behavior; the performance rationale is sound regardless, and the widget is eventually updated via snapshot or other paths.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. Phase 0004 is complete. All acceptance criteria are met, all laws are satisfied, docs are reconciled. Weighed and found true.
