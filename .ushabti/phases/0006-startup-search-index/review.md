# Review: Phase 0006 — Startup Search Index Build

## Summary

Phase 0006 adds a startup reindex call inside `AppBootstrapper.installReconciler` so that the FTS5 search index is populated at app launch when Magic Chat is enabled. All three steps are implemented correctly. All six acceptance criteria pass. No law violations. No style violations. Documentation is reconciled. Build number incremented to 9 / 1.1.5 (L20).

## Verified

**S001 — AppBootstrapper.installReconciler startup reindex block**

`AppBootstrapper.swift` lines 172–185 contain the startup block. It is inside the `if runOnStartup` branch. It wraps the work in `Task { @MainActor in }`, consistent with the CloudKit-change path. It gates execution on `searchIndexService.canReindexAllNotes()`. It creates a `Logger(subsystem: "com.adamdrew.takenote", category: "AppBootstrapper")` and logs at `.info` level: `"RAG search startup reindex triggered."` It fetches all `Note` records using `FetchDescriptor<Note>()` from `container.mainContext` and passes `(note.uuid, note.content)` tuples to `searchIndexService.reindexAll`. The implementation exactly mirrors the CloudKit-change reindex path at lines 144–156.

**AC1** — Startup reindex fires in `runOnStartup: true` path, gated on `canReindexAllNotes()`. PASS.

**AC2** — Chat feature flag gate enforced: `canReindexAllNotes()` returns `false` when `chatFeatureFlagEnabled == false`. PASS.

**AC3** — Note fetch uses `container.mainContext` and `FetchDescriptor<Note>()`. Tuples mapped as `(note.uuid, note.content)`. Consistent with CloudKit-change path. PASS.

**AC4** — No new types, properties, or parameters introduced. `installReconciler` signature unchanged. PASS.

**S002 — search-system.md "When Indexing Runs" section**

Line 41 of `search-system.md` adds the third bullet: **Startup** — triggered once per session from `AppBootstrapper.installReconciler()` when `runOnStartup: true` and `canReindexAllNotes()` is satisfied. Includes the DEBUG behavior note. Three triggers now listed: single note, bulk (CloudKit), startup.

**AC5** — Three indexing triggers documented. PASS.

**S003 — supporting-systems.md installReconciler section**

Lines 44–46 of `supporting-systems.md` add an accurate prose description of the startup reindex behavior: gated on `canReindexAllNotes()`, fetches all notes from `container.mainContext`, passes tuples to `reindexAll`, purpose stated as ensuring the FTS5 index is populated before any Magic Chat interaction.

**AC6** — `installReconciler` documentation reflects startup reindex behavior. PASS.

**Law compliance**

- L07: `canReindexAllNotes()` returns `false` when `chatFeatureFlagEnabled == false`. The startup path is fully gated. PASS.
- L13: `SearchIndexService.index` remains typed as `SearchIndex` (FTS5). No changes to backing implementation. PASS.
- L09: No new app-wide state managers. PASS.
- L17/L18/L19: Both doc files updated and listed in `touched`. Docs accurately reflect code. PASS.
- L20: Bumped `CURRENT_PROJECT_VERSION` from 8 to 9 and `MARKETING_VERSION` from 1.1.4 to 1.1.5 across all four occurrences in `TakeNote.xcodeproj/project.pbxproj`. PASS.

**Style compliance**

Logger uses `os.Logger` with correct subsystem (`com.adamdrew.takenote`) and category (`AppBootstrapper`). Log message is `.info` level as required by Phase constraints. No `print()` in new production code paths. PASS.

## Issues

None.

## Required follow-ups

None.

## Decision

GREEN. Phase 0006 is complete.

Build: 9 (1.1.5)
