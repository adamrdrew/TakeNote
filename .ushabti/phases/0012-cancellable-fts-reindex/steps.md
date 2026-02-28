# Steps

## S001: Add cancellation check inside `SearchIndex.reindex(_ notes:)`

**Intent:** Allow a bulk reindex to bail out early when its owning Task is cancelled, without leaving partial data in the index.

**Work:**
- In `/Users/adam/Development/TakeNote/TakeNote/Library/SearchIndex.swift`, inside `reindex(_ notes: [(UUID, String)])`, add a `Task.isCancelled` check at the top of the `for (id, md) in notes` loop body.
- If `Task.isCancelled` is `true`, `return` immediately (before writing any rows for that note). Because the entire loop runs inside `db.transaction`, SQLite will roll back the uncommitted work automatically when the function returns early.

**Done when:** `SearchIndex.reindex(_ notes:)` contains a cancellation guard inside the `for` loop.

---

## S002: Refactor `SearchIndexService.reindexAll` to use a stored cancellable Task

**Intent:** Replace the time-based throttle with a cancel-and-restart pattern so new reindex requests always produce a fresh index regardless of the cooldown.

**Work:**
- In `/Users/adam/Development/TakeNote/TakeNote/Library/SearchIndexService.swift`:
  - Add `private var reindexTask: Task<Void, Never>?` property.
  - Remove `var lastReindexAllDate: Date = .distantPast`.
  - Remove the `canReindexAllNotes()` method entirely.
  - Rewrite `reindexAll(_ noteData:)`:
    - Cancel `reindexTask` (if non-nil) before proceeding.
    - Remove the `canReindexAllNotes()` guard at the top.
    - Set `isIndexing = true`.
    - Assign a new `Task { ... }` to `reindexTask`. Inside the task body:
      - Call `index.reindex(noteData)`.
      - After the call returns, check `reindexTask?.isCancelled` — if the task was cancelled while `reindex` was running (i.e., a later call cancelled this one), set `isIndexing = false` and return without logging completion.
      - Otherwise set `isIndexing = false` and log completion as before.
    - The `chatFeatureFlagEnabled` check that returns early (already present in `reindexAll`) must be preserved exactly.

**Done when:** `SearchIndexService` has no `canReindexAllNotes` and no `lastReindexAllDate`; `reindexAll` stores its task in `reindexTask` and cancels any prior task on entry.

---

## S003: Remove `canReindexAllNotes()` guards from `AppBootstrapper.installReconciler`

**Intent:** Ensure the startup reindex and the `NSPersistentStoreRemoteChange` reindex always fire, relying on cancellation rather than the throttle to manage overlap.

**Work:**
- In `/Users/adam/Development/TakeNote/TakeNote/Library/AppBootstrapper.swift`, inside `installReconciler`:
  - In the `NSPersistentStoreRemoteChange` observer block: remove the `if searchIndexService.canReindexAllNotes()` guard; call `searchIndexService.reindexAll(...)` unconditionally (the note fetch and reindex call are otherwise unchanged).
  - In the `runOnStartup` block: remove the `if searchIndexService.canReindexAllNotes()` guard; call `searchIndexService.reindexAll(...)` unconditionally.

**Done when:** Neither the remote-change observer nor the startup block checks `canReindexAllNotes()`. Both call `reindexAll` directly.

---

## S004: Add `onChange(of: notes.count)` handler in `NoteList`

**Intent:** Trigger a fresh full reindex whenever the note count changes (including CloudKit hydration on iPhone), so the index is always consistent with the live store.

**Work:**
- In `/Users/adam/Development/TakeNote/TakeNote/Views/NoteList/NoteList.swift`, inside the `body` computed property, add an `.onChange(of: notes.count)` modifier on the outermost `VStack` (or the `List`) — consistent with the existing `.onChange(of: takeNoteVM.selectedNotes)` placement.
- The handler body: `search.reindexAll(notes.map { ($0.uuid, $0.content) })`.
- No other changes to `NoteList`.

**Done when:** `NoteList` contains an `onChange(of: notes.count)` modifier whose action calls `search.reindexAll` with the full notes array mapped to `(UUID, String)` tuples.

---

## S005: Update documentation

**Intent:** Keep `.ushabti/docs/` accurate so future agents plan correctly against the new behavior (L17, L18, L19).

**Work:**
- In `/Users/adam/Development/TakeNote/.ushabti/docs/search-system.md`:
  - Update the `SearchIndexService` properties table: remove `lastReindexAllDate`.
  - Update the `SearchIndexService` methods list: remove `canReindexAllNotes()`; add `reindexTask` as a private stored property.
  - Update `reindexAll` description to reflect the cancel-and-restart pattern.
  - Update the "When Indexing Runs" section: add the `NoteList.onChange(of: notes.count)` trigger; update the startup and CloudKit bulk entries to note that the `canReindexAllNotes()` guard has been removed.
  - Remove any reference to the 10-minute rate limit.
- In `/Users/adam/Development/TakeNote/.ushabti/docs/supporting-systems.md`:
  - Update the `installReconciler` description to reflect that `reindexAll` is called unconditionally (no `canReindexAllNotes()` guard) in both the startup and `NSPersistentStoreRemoteChange` paths.

**Done when:** Both doc files accurately describe the new cancellable reindex behavior and contain no references to `canReindexAllNotes`, `lastReindexAllDate`, or the 10-minute cooldown.