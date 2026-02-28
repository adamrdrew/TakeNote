# Phase 0012: Cancellable FTS Reindex with Note-Count Trigger

## Intent
Fix a startup race condition on iPhone where the FTS reindex fires before SwiftData/CloudKit has hydrated the local store, leaving the index empty. The 10-minute cooldown then blocks any subsequent reindex attempt during the session.

The fix has two parts:
1. Replace the 10-minute throttle with a cancel-and-restart pattern in `SearchIndexService`. Any call to `reindexAll` cancels the in-flight reindex task and starts a fresh one. The bulk `reindex(_ notes:)` method in `SearchIndex` checks `Task.isCancelled` between note iterations so it can bail out promptly.
2. Add an `onChange(of: notes.count)` handler in `NoteList` that fires `search.reindexAll` whenever the note count changes (notes added, deleted, or synced from CloudKit). Because `NoteList` already holds `@Query() var notes` and `@Environment(SearchIndexService.self) private var search`, this is a natural insertion point with no new dependencies.

The startup reindex in `AppBootstrapper.installReconciler` and the `NSPersistentStoreRemoteChange` reindex are both retained; their `canReindexAllNotes()` guards are simply removed so they always fire. If a `NoteList.onChange` reindex supersedes them, cancellation handles the overlap.

## Scope

**In scope:**
- Add `private var reindexTask: Task<Void, Never>?` to `SearchIndexService`
- Cancel `reindexTask` before starting a new one in `reindexAll`
- Store the new task in `reindexTask`
- Set `isIndexing = false` when a task exits due to cancellation
- Add `Task.isCancelled` check between note iterations inside `SearchIndex.reindex(_ notes:)`
- Delete `canReindexAllNotes()`, `lastReindexAllDate`, and all call sites in `SearchIndexService` and `AppBootstrapper`
- Add `onChange(of: notes.count)` handler in `NoteList.body` that calls `search.reindexAll(notes.map { ($0.uuid, $0.content) })`
- Update `.ushabti/docs/search-system.md` and `.ushabti/docs/supporting-systems.md` to reflect all changes

**Out of scope:**
- `SearchIndex.swift` schema, FTS5 table definition, or any query method
- `SearchIndexService.reindex(note:)` (single-note reindex path)
- `SearchIndex.searchNatural`, `searchNoteIDs`, or any other query method
- `TakeNoteVM` gaining any reference to `SearchIndexService` (L09)
- `chatFeatureFlagEnabled` gating inside `reindexAll` (already present; must not be removed)
- The `NSPersistentStoreRemoteChange` observer itself (kept; only the `canReindexAllNotes()` guard is removed)

## Constraints
- L07: `chatFeatureFlagEnabled` gating inside `reindexAll` must be preserved exactly as-is.
- L09: `TakeNoteVM` must not gain a reference to `SearchIndexService`.
- L13: `SearchIndexService.index` must remain of type `SearchIndex`.
- Style: use `os.Logger` for any new log lines; no `print()`.
- Style: `SearchIndex` is `internal final class`; the cancellation check should use `try Task.checkCancellation()` or a manual `if Task.isCancelled { return }` guard inside the loop body, not a throwing rethrow that changes the method signature.

## Acceptance criteria
- `SearchIndexService` has no `canReindexAllNotes()` method and no `lastReindexAllDate` property.
- `SearchIndexService.reindexAll` stores its Task in `reindexTask`, cancels any previous task before starting, and sets `isIndexing = false` on cancellation exit.
- `SearchIndex.reindex(_ notes:)` checks `Task.isCancelled` inside the loop and returns early (without committing the partial transaction) when cancelled.
- `NoteList.body` contains an `onChange(of: notes.count)` modifier that calls `search.reindexAll(notes.map { ($0.uuid, $0.content) })`.
- `AppBootstrapper.installReconciler` fires `reindexAll` unconditionally (no `canReindexAllNotes()` guard) for both the startup path and the `NSPersistentStoreRemoteChange` path.
- The app builds without errors or warnings.
- `.ushabti/docs/search-system.md` and `.ushabti/docs/supporting-systems.md` are updated to reflect the new behavior.

## Risks / notes
- `SearchIndex.reindex(_ notes:)` currently wraps the entire bulk operation in a single `db.transaction`. To support mid-loop cancellation, the check must be placed inside the loop, which means a cancellation will leave the transaction uncommitted — SQLite rolls it back automatically. This is the correct and safe behavior: a cancelled reindex leaves the previous index state intact.
- The `onChange(of: notes.count)` approach fires on any note count change — additions, deletions, and CloudKit arrivals. This is intentional. An extra reindex is cheap because the cancellation mechanism eliminates redundant work.
- On macOS the startup reindex and `NoteList.onChange` may race. The cancellation mechanism resolves this correctly; whichever fires last wins.
