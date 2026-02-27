# Steps

## S001: Add startup reindex call in AppBootstrapper.installReconciler

**Intent:** Trigger `reindexAll` at startup when the feature flag is on and the rate limit is satisfied, so the search index is populated before any Magic Chat interaction.

**Work:**
- In `AppBootstrapper.installReconciler`, immediately after `try? reconciler.runOnce()` in the `if runOnStartup` block, add a startup reindex:
  - Check `searchIndexService.canReindexAllNotes()`
  - If true, fetch all `Note` records from `container.mainContext` using `FetchDescriptor<Note>()`
  - Call `searchIndexService.reindexAll` with the mapped `(note.uuid, note.content)` tuples
- Wrap the fetch and call in a `Task { @MainActor in ... }` consistent with the CloudKit-change path in the same file
- Add a `logger` call at `.info` level before the reindex: `"RAG search startup reindex triggered."`

**Done when:** `installReconciler` contains a startup reindex block immediately after `reconciler.runOnce()`, gated on `canReindexAllNotes()`, that fetches all notes and calls `reindexAll`.

---

## S002: Update search-system.md

**Intent:** Keep documentation current with the new startup trigger so future agents and developers understand all indexing trigger points.

**Work:**
- In `.ushabti/docs/search-system.md`, under the "When Indexing Runs" section, add a third bullet:
  - **Startup**: triggered once per session from `AppBootstrapper.installReconciler` when `runOnStartup: true` and `canReindexAllNotes()` is satisfied (feature flag on, not indexing, 10-minute cooldown elapsed). Runs at app launch before any user interaction with Magic Chat.

**Done when:** `search-system.md` lists three indexing triggers: single note, bulk (CloudKit), and startup.

---

## S003: Update supporting-systems.md

**Intent:** The `installReconciler` documentation currently does not mention that it triggers a search reindex on startup. Update it to reflect the new behavior.

**Work:**
- In `.ushabti/docs/supporting-systems.md`, in the `installReconciler` section, add a note that when `runOnStartup` is `true` and the feature flag is enabled, a startup `reindexAll` is also triggered after the reconciler runs.

**Done when:** `supporting-systems.md` accurately describes the startup reindex behavior of `installReconciler`.
