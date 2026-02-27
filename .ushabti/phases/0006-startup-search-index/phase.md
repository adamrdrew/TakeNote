# Phase 0006: Startup Search Index Build

## Intent

When Magic Chat is enabled, the FTS5 search index must be populated at startup so that RAG retrieval works immediately. Currently the only trigger for `reindexAll` is an `NSPersistentStoreRemoteChange` notification, which is non-deterministic and may not fire during a given session. Existing users who enable the feature flag could use Magic Chat for an entire session without any notes indexed, receiving empty or hallucinated responses.

This phase adds a startup reindex call inside `AppBootstrapper.installReconciler` that fires when the feature flag is on and `canReindexAllNotes()` returns `true`. Because `lastReindexAllDate` initializes to `.distantPast`, this condition is always satisfied on the first run of a session. In Release builds the on-disk index persists, so subsequent launches after a successful reindex will not re-run unnecessarily (the 10-minute rate limit resets each process launch, but the index on disk already has content — the reindex will still run once per session, which is acceptable and intentional for correctness).

## Scope

**In scope:**
- Add a startup reindex call in `AppBootstrapper.installReconciler` that runs when `runOnStartup` is `true`, the feature flag is enabled, and `canReindexAllNotes()` is satisfied
- Update `search-system.md` to document the new startup trigger
- Update `supporting-systems.md` to document the new behavior of `installReconciler`

**Out of scope:**
- Persisting `lastReindexAllDate` across launches to avoid redundant reindexes on subsequent launches (a per-session startup reindex is acceptable)
- Any UI indication of startup indexing (the existing `isIndexing` observable property already covers this if needed)
- Changes to rate-limit logic or cooldown duration
- Changes to the CloudKit remote-change reindex path
- Any changes to `SearchIndex` or `SearchIndexService` internals

## Constraints

- L07: The chat feature flag (`chatFeatureFlagEnabled`) must gate all search indexing. The startup reindex must not run when the flag is `false`. `canReindexAllNotes()` already enforces this, but the call site must be inside the `runOnStartup` block.
- L13: `SearchIndexService` must continue using `SearchIndex` (FTS5). No changes to the backing implementation.
- L09: No new app-wide state managers. The fix is a call-site addition only.
- L17: Docs must be updated to reflect the new startup trigger.
- Style: Use `os.Logger` for the startup reindex log line, consistent with the existing `logger.info("RAG search reindex running.")` in `SearchIndexService.reindexAll`.

## Acceptance criteria

1. When the chat feature flag is enabled and `canReindexAllNotes()` returns `true` at startup, `reindexAll` is called during `installReconciler` execution (in the `runOnStartup: true` path).
2. When the chat feature flag is disabled, the startup reindex path is not taken (enforced by `canReindexAllNotes()` returning `false`).
3. The startup reindex fetches all `Note` records from `container.mainContext` and passes their `(uuid, content)` tuples to `searchIndexService.reindexAll`, consistent with the CloudKit-change path.
4. The fix introduces no new types, no new properties, and no new parameters to existing functions.
5. `search-system.md` documents the new startup trigger under "When Indexing Runs."
6. `supporting-systems.md` documents the updated behavior of `installReconciler`.

## Risks / notes

- The startup reindex runs in an unstructured `Task` (as `reindexAll` already does), so it will not block app launch.
- In DEBUG builds the index is in-memory and starts empty every launch. The startup reindex will run on every DEBUG launch, which is expected and harmless.
- The fetch of all notes at startup is the same operation performed on every `NSPersistentStoreRemoteChange`. The data volume is identical to what is already happening on CloudKit sync.
