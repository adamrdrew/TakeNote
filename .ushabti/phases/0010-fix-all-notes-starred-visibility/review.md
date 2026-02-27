# Review: Phase 0010 — Fix All Notes Starred Note Visibility

## Summary

All three steps are implemented correctly. The prior kickback defect (L20 version bump) has been resolved. This Phase is weighed and found true.

## Verified

**S001 — folderHasStarredNotes() fix:**
The function at `TakeNote/Views/NoteList/NoteList.swift` lines 182–187 reads:

```swift
func folderHasStarredNotes() -> Bool {
    if takeNoteVM.selectedContainer?.isAllNotes == true {
        return sortedNotes.contains { $0.starred }
    }
    return takeNoteVM.selectedContainer?.notes.contains { $0.starred } ?? false
}
```

This exactly matches the S001 specification. The `isAllNotes` branch uses `sortedNotes` (already derived from `filteredNotes`, which handles the virtual All Notes container correctly). All other containers fall through to the original path. `NoteContainer.isAllNotes` confirmed as an `internal var Bool` field on the model.

**Acceptance criteria AC1–AC5:** Verified against the code. The fix correctly addresses all sectioning scenarios (starred + unstared notes, all starred, none starred, other containers unchanged).

**AC6 — views.md documentation:**
`.ushabti/docs/views.md` line 85 accurately describes both branches of `folderHasStarredNotes()`, including the explanation that the All Notes virtual container's `NoteContainer.notes` computed property always returns an empty array. L17/L18/L19 satisfied.

**S003 — L20 version bump:**
All eight occurrences in `TakeNote.xcodeproj/project.pbxproj` confirmed:
- Four `CURRENT_PROJECT_VERSION = 13` (incremented from 12)
- Four `MARKETING_VERSION = 1.1.9` (incremented from 1.1.8)
L20 satisfied.

**Laws reviewed:**
- L01 (platform targets): No deployment target changes. No `#available` below macOS 26.
- L02/L03 (SwiftData schema): No model changes.
- L04–L06 (LLM): No LLM code touched.
- L07–L16: Not applicable to this change.
- L17/L18/L19 (docs reconciliation): views.md updated and accurately reflects the code change.
- L20 (version bump): All four entries of each field incremented correctly.

**Style:** Change is read-only. No naming, structural, or pattern violations introduced.

## Issues

None.

## Decision

GREEN — all acceptance criteria met, all laws satisfied, docs reconciled, version numbers correctly incremented.
