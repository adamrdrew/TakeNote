# Review: Phase 0012 — Cancellable FTS Reindex with Note-Count Trigger

## Summary

Phase 0012 is GREEN. All five implementation steps are complete and correct. The previously kicked-back S006 step — which required restoring a `chatFeatureFlagEnabled` guard inside `reindexAll` — has been deleted because it directly contradicts the updated L07. Under the current laws, FTS indexing must run unconditionally and must NOT be gated by the chat feature flag. The code is already in the correct state: no such guard exists. Build version bumped to 15 / 1.1.11.

---

## Context: Previous Kickback Was Based on a Stale Law

The prior review found an L07 violation because `chatFeatureFlagEnabled` gating had been removed from `reindexAll`. That review referenced L07 as requiring the gate. L07 has since been updated by Lawgiver: FTS indexing is now explicitly always-on and must NOT be gated by the feature flag. The current L07 states:

> "FTS indexing (`SearchIndexService.reindex` and `reindexAll`) MUST run unconditionally, regardless of the value of `chatFeatureFlagEnabled`."

S006 contradicted the updated law and was removed from both `steps.md` and `progress.yaml` before this review was declared GREEN.

---

## Verified

**S001 — SearchIndex cancellation check (PASS)**

`TakeNote/Library/SearchIndex.swift` line 146: `if Task.isCancelled { return }` is present at the top of the `for (id, md) in notes` loop body inside `reindex(_ notes:)`. Early return leaves the transaction uncommitted; SQLite rolls it back automatically. Matches "done when" condition exactly.

**S002 — Cancellable Task in SearchIndexService (PASS)**

`TakeNote/Library/SearchIndexService.swift`:
- `private var reindexTask: Task<Void, Never>?` is present (line 30).
- `lastReindexAllDate` and `canReindexAllNotes()` are absent from the file (confirmed via search).
- `reindexAll` cancels any prior task (`reindexTask?.cancel()`), sets `isIndexing = true`, assigns a new `Task` to `reindexTask`, checks `Task.isCancelled` after `index.reindex` returns, and sets `isIndexing = false` on both the cancelled and completed paths.
- No `chatFeatureFlagEnabled` guard is present in `reindexAll` — correct under the updated L07.

**S003 — AppBootstrapper guards removed (PASS)**

`TakeNote/Library/AppBootstrapper.swift`: The `NSPersistentStoreRemoteChange` observer block (lines 148–153) and the `runOnStartup` block (lines 172–179) both call `searchIndexService.reindexAll` unconditionally. No `canReindexAllNotes()` call exists anywhere in the file.

**S004 — onChange(of: notes.count) in NoteList (PASS)**

`TakeNote/Views/NoteList/NoteList.swift` lines 350–352: `.onChange(of: notes.count) { _, _ in search.reindexAll(notes.map { ($0.uuid, $0.content) }) }` is present. Matches "done when" condition exactly.

**S005 — Documentation (PASS)**

`.ushabti/docs/search-system.md`: `lastReindexAllDate` is absent from the properties table; `reindexTask` is present. `canReindexAllNotes()` is absent from the methods list. `reindexAll` description accurately describes the cancel-and-restart pattern and states there is no rate-limit. "When Indexing Runs" section includes the `NoteList.onChange(of: notes.count)` trigger and correctly notes that bulk and startup reindexes fire unconditionally.

`.ushabti/docs/supporting-systems.md`: `installReconciler` description accurately states both reindex calls are unconditional (no `canReindexAllNotes()` guard).

Neither doc references `chatFeatureFlagEnabled` in the context of FTS indexing, which is correct.

**S006 — Deleted (CORRECT)**

S006 was added by the previous review to restore a `chatFeatureFlagEnabled` gate in `reindexAll`. That step contradicted the updated L07 and has been removed from `steps.md` and `progress.yaml`. No follow-up implementation is required; the code is already in the correct state.

---

## Law Checks

- **L01**: No `#available` checks for pre-macOS-26 versions. Pass.
- **L02**: No new `@Model` types. Pass.
- **L07** (current): `reindexAll` runs unconditionally — no `chatFeatureFlagEnabled` guard present. `chatFeatureFlagEnabled` is used only in chat UI surfaces (`TakeNoteApp.swift`, `MainWindow.swift`, `WindowCommands.swift`). Pass.
- **L09**: `TakeNoteVM` has no reference to `SearchIndexService`. Pass.
- **L13**: `SearchIndexService.index` is of type `SearchIndex` (FTS5). Pass.
- **L17/L18/L19**: Docs updated accurately; no stale references to removed APIs. Pass.
- **L20**: `CURRENT_PROJECT_VERSION` bumped from 14 to 15. `MARKETING_VERSION` bumped from 1.1.10 to 1.1.11. All four occurrences of each field updated. Pass.

---

## Style Checks

- `os.Logger` used; no `print()` introduced. Pass.
- New log line uses established subsystem/category pattern. Pass.
- No sub-view computed properties introduced; not applicable.

---

## Version Bump

`CURRENT_PROJECT_VERSION`: 14 → 15
`MARKETING_VERSION`: 1.1.10 → 1.1.11
All four occurrences of each field in `TakeNote.xcodeproj/project.pbxproj` updated.

---

## Decision

GREEN. Phase 0012 is complete. Weighed and found true.

Hand off to Ushabti Scribe for the next Phase.
