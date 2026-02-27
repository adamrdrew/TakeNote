# Project Laws

## Preamble

These laws define the non-negotiable invariants for TakeNote across all Phases, implementations, and refactors. They are binding on every agent and reviewer. A Phase cannot be marked GREEN/complete if any law is violated. Laws may only be changed by an explicit user instruction to Ushabti Lawgiver.

---

## Laws

### L01 — Platform Minimum Versions

- **Rule:** All targets MUST require macOS 26 or later and iOS 26 or later. No code may introduce deployment-target compatibility shims for earlier OS versions.
- **Rationale:** TakeNote depends on APIs (FoundationModels, SwiftData CloudKit integration, SwiftUI features) that are only available at these minimum versions. Lowering the deployment target would create a false compatibility surface.
- **Enforcement:** Reviewer checks `MACOSX_DEPLOYMENT_TARGET` and `IPHONEOS_DEPLOYMENT_TARGET` in the Xcode project settings. Any `#available` check for a version below macOS 26 / iOS 26 is a violation.
- **Exceptions:** None.

---

### L02 — SwiftData and CloudKit as Sole Persistence for User Data

- **Rule:** All user data persistence MUST use the SwiftData `ModelContainer` backed by `iCloud.com.adamdrew.takenote`. The three model types `Note`, `NoteContainer`, and `NoteLink` are the only `@Model` types. No alternative persistence mechanism (raw CoreData, direct SQLite for user data, flat-file note storage) may be introduced.
- **Rationale:** User data integrity and iCloud sync correctness depend on all writes flowing through SwiftData's change tracking and CloudKit sync pipeline.
- **Enforcement:** Reviewer verifies no new `@Model` classes are introduced without updating `L03`. No `NSManagedObjectContext` or direct SQLite writes to non-search databases are present.
- **Scope:** User-facing data. The FTS5 search database (`search.sqlite`) is a derived index, not user data, and is exempt.
- **Exceptions:** None.

---

### L03 — Schema Change Protocol

- **Rule:** Any change to the schema of `Note`, `NoteContainer`, or `NoteLink` (adding, removing, or renaming a persisted field or relationship) MUST be accompanied by: (1) bumping `ckBootstrapVersionCurrent` in `TakeNoteApp.swift`, and (2) promoting the schema change to the production CloudKit container.
- **Rationale:** SwiftData + CloudKit schema mismatches cause silent data corruption or migration failures on existing user devices. The version bump triggers re-bootstrapping on next launch.
- **Enforcement:** Reviewer checks that any diff touching model files also bumps `ckBootstrapVersionCurrent`. Comments marked `// Hey! // Hey you!` in model files are reminders of this requirement.
- **Exceptions:** Changes to `@Transient` properties (e.g., `aiSummaryIsGenerating`) require no version bump, as they are not persisted.

---

### L04 — Apple FoundationModels as the Sole LLM Runtime

- **Rule:** All LLM inference MUST go through `Apple.FoundationModels.SystemLanguageModel.default`. No third-party LLM APIs (OpenAI, Anthropic, Ollama, etc.), remote API calls for model inference, or alternative on-device model runtimes may be introduced.
- **Rationale:** TakeNote is designed as a fully private, on-device AI experience. All inference stays on the user's device with Apple's privacy guarantees.
- **Enforcement:** Reviewer verifies no network calls exist for LLM inference. No SPM dependencies or frameworks that wrap external LLM APIs are added.
- **Exceptions:** None.

---

### L05 — AI Availability Gate Required Before Any LLM Call

- **Rule:** All code paths that invoke a `LanguageModelSession` MUST check that AI is available before proceeding. The canonical check is `TakeNoteVM.aiIsAvailable` (which evaluates `languageModel.availability == .available`). Model-level guards use `Note.canGenerateAISummary()`.
- **Rationale:** Apple Intelligence may be unavailable (unsupported device, disabled by user, parental controls). Attempting inference without the availability guard results in errors and broken UI.
- **Enforcement:** Reviewer traces every `LanguageModelSession` instantiation and confirms that the call is guarded by an `aiIsAvailable` or equivalent availability check.
- **Exceptions:** None.

---

### L06 — Stateless LLM Sessions

- **Rule:** A new `LanguageModelSession` MUST be created for each individual LLM response. Sessions MUST NOT be reused across conversation turns or across separate invocations.
- **Rationale:** Reusing sessions accumulates context in the session object, which causes context window overflow errors as conversation history grows. Full conversation history is assembled in the prompt text instead.
- **Enforcement:** Reviewer checks that no `LanguageModelSession` instance is stored as a persistent property on a class or struct that survives across multiple calls.
- **Exceptions:** None.

---

### L07 — Magic Chat Feature Flag Must Gate All Chat Surfaces

- **Rule:** The `MagicChatEnabled` Info.plist boolean MUST gate all three of: (1) the Chat window/popover UI, (2) search indexing for chat RAG (`SearchIndexService.reindex` and `reindexAll`), and (3) the Chat toolbar button. When `chatFeatureFlagEnabled` is `false`, none of these may be reachable.
- **Rationale:** Magic Chat is a separately controllable feature. Indexing notes when chat is disabled wastes resources and is unexpected behavior. Exposing chat UI when disabled is a product invariant violation.
- **Enforcement:** Reviewer checks that all three surfaces consult `chatFeatureFlagEnabled` before executing. A change that adds a new chat entry point MUST also gate it on this flag.
- **Exceptions:** Magic Assistant (inline text transformation inside NoteEditor) is distinct from Magic Chat and is not gated by this flag.

---

### L08 — Widgets Must Access Data Only via App Group Snapshot

- **Rule:** Widget extensions MUST read note data exclusively through `SnapshotController.readSnapshot()`, which reads `group.TakeNote/snapshot.json`. Widget extensions MUST NOT access the SwiftData `ModelContainer` directly.
- **Rationale:** Widget extensions run in a separate process. SwiftData's CloudKit-backed store is not safely shared between processes. The App Group snapshot is the defined inter-process data contract.
- **Enforcement:** Reviewer checks that no widget target code imports or instantiates `ModelContainer`, `ModelContext`, or any `@Model` type directly. All data access goes through `ContainerProvider` and `SnapshotController.readSnapshot()`.
- **Exceptions:** None.

---

### L09 — TakeNoteVM Is the Sole App-Wide State Manager

- **Rule:** `TakeNoteVM` MUST remain the single `@Observable`, `@MainActor`-confined central state manager. It MUST be shared app-wide via the SwiftUI environment (`.environment(takeNoteVM)`). No parallel global state managers or singletons for app-level state may be introduced.
- **Rationale:** Centralizing state in `TakeNoteVM` ensures consistent UI updates across all windows and avoids state divergence. The `@MainActor` confinement enforces thread safety.
- **Enforcement:** Reviewer verifies that no new `@Observable` or `ObservableObject` class is introduced to manage state that properly belongs in `TakeNoteVM`. New application-scoped state MUST be added to `TakeNoteVM` or a clearly scoped service object (e.g., `SearchIndexService`).
- **Exceptions:** `SearchIndexService` and `NoteLinkManager` are legitimate service objects that hold their own scoped state. `NoteEditorWindow` creates its own `TakeNoteVM` instance for the detached editor window, which is intentional isolation.

---

### L10 — Notes Must Be Trashed Before Permanent Deletion

- **Rule:** User notes MUST be moved to the Trash folder before they can be permanently deleted. Permanent deletion MUST only occur via `TakeNoteVM.emptyTrash()`, which operates exclusively on notes already in the Trash container. No code path may permanently delete a note that is not in Trash.
- **Rationale:** Permanent data loss is unrecoverable. The Trash step provides a safety buffer and is a core UX contract.
- **Enforcement:** Reviewer checks that no `modelContext.delete(note)` call exists outside `emptyTrash()`. The delete rule on `Note.folder` is `.noAction`; reviewer confirms this has not been changed.
- **Exceptions:** The DEBUG "Delete Everything" command (gated on `#if DEBUG`) is exempt.

---

### L11 — System Containers Are Non-Deletable and Must Be Reconciled

- **Rule:** The four system containers (Inbox, Trash, Starred, Buffer) MUST have `canBeDeleted = false` at all times. `SystemFolderReconciler.runOnce()` MUST be invoked on every `NSPersistentStoreRemoteChange` notification to detect and merge CloudKit-induced duplicates.
- **Rationale:** System containers are structural invariants of the data model. CloudKit sync from multiple devices can create duplicate system containers; the reconciler preserves data integrity by merging them.
- **Enforcement:** Reviewer checks that no code sets `canBeDeleted = true` on a system container. Reviewer checks that `AppBootstrapper.installReconciler()` remains wired to `NSPersistentStoreRemoteChange`.
- **Exceptions:** None.

---

### L12 — Note UUID Must Not Be Reassigned After Creation

- **Rule:** `Note.uuid` has a private setter and MUST NOT be reassigned after the note is created. It is the stable, permanent identifier for a note across the FTS index, vector index, `NoteLink` graph, deep links (`takenote://note/<UUID>`), and widget snapshots.
- **Rationale:** Reassigning a UUID would silently break all cross-references: FTS index entries become orphaned, deep links become invalid, `NoteLink` records reference a nonexistent UUID, and widget URLs stop working.
- **Enforcement:** Reviewer confirms that no code accesses or mutates `Note.uuid` via reflection, `setValue(_:forKey:)`, or any other mechanism that bypasses the private setter.
- **Exceptions:** SwiftData's internal hydration of the `uuid` field from the persistent store is the only permitted setter invocation.

---

### L13 — FTS5 SearchIndex Is the Authoritative Search Backend

- **Rule:** `SearchIndexService` MUST use `SearchIndex` (FTS5 via SQLite) as its backing implementation. `VectorSearchIndex` MUST NOT be wired into `SearchIndexService` or any production code path without an explicit decision recorded in `.ushabti/laws.md` to replace the search backend.
- **Rationale:** `VectorSearchIndex` is an experimental, in-memory-only, non-persisted implementation. Silently switching to it would break search persistence across launches and change relevance behavior.
- **Enforcement:** Reviewer checks that `SearchIndexService.index` is of type `SearchIndex`, not `VectorSearchIndex`. Any PR that wires `VectorSearchIndex` into the service layer is a law violation unless this law is first updated.
- **Exceptions:** Test code and DEBUG-only investigation code may use `VectorSearchIndex` in isolation.

---

### L14 — AppIntents Must Access Shared State via AppDependencyManager

- **Rule:** `AppIntent` implementations MUST access `TakeNoteVM` and `ModelContainer` exclusively through `AppDependencyManager` using the registered string keys (`"TakeNoteVM"` and `"ModelContainer"`). They MUST NOT capture environment objects, use singletons, or hold direct references to these objects.
- **Rationale:** `AppIntent` handlers execute outside the SwiftUI view hierarchy. The `AppDependencyManager` is the safe, asynchronous mechanism for obtaining `@MainActor`-confined state from an intent execution context.
- **Enforcement:** Reviewer verifies that all `AppIntent` implementations use `@Dependency(key:)` for both `TakeNoteVM` and `ModelContainer` access. No `@EnvironmentObject` or global variable access to these objects is permitted in intent code.
- **Exceptions:** None.

---

### L15 — CommandRegistry Lifecycle Must Be Honored

- **Rule:** Any list item (in `NoteList`, `Sidebar`, or any future equivalent) that responds to menubar commands MUST register its command closure in `.onAppear` and MUST unregister it in `.onDisappear`. Both registration and unregistration are required; either alone is insufficient.
- **Rationale:** The `CommandRegistry` pattern is a workaround for a SwiftUI limitation. Stale registrations cause menubar commands to silently execute on off-screen items. Missing registrations cause commands to silently do nothing for visible items.
- **Enforcement:** Reviewer checks that every new `List` item that calls `registerCommand` also calls `unregisterCommand` in a matching `.onDisappear`. A one-way registration is a defect.
- **Exceptions:** None.

---

### L16 — Scribe Must Consult Docs Before Planning

- **Rule:** Scribe MUST read and incorporate `.ushabti/docs/` documentation before producing any Phase plan. Understanding documented systems (architecture, data models, view model, AI features, search system, supporting systems) is a prerequisite to coherent planning.
- **Rationale:** Plans produced without consulting docs will conflict with documented invariants, miss existing abstractions, or duplicate work.
- **Enforcement:** Overseer verifies that Scribe's Phase plan references relevant doc sections for any system being modified.
- **Exceptions:** None.

---

### L17 — Builder Must Consult and Maintain Docs

- **Rule:** Builder MUST consult `.ushabti/docs/` during implementation. When code changes affect a documented system, Builder MUST update the relevant documentation file(s) in `.ushabti/docs/`. Updated docs files MUST be included in the `touched` list in `progress.yaml`.
- **Rationale:** Docs are both a resource and a maintenance responsibility. Stale docs mislead future agents and developers.
- **Enforcement:** Overseer verifies that any implementation touching a documented system is accompanied by a corresponding docs update.
- **Exceptions:** None.

---

### L18 — Overseer Must Reconcile Docs Before Approving Phase Completion

- **Rule:** Overseer MUST verify that `.ushabti/docs/` accurately reflects all code changes made during a Phase before marking the Phase GREEN/complete. A Phase with stale, missing, or inaccurate documentation MUST NOT be marked complete.
- **Rationale:** Docs drift compounds across Phases and eventually renders the docs system useless as a planning and review resource.
- **Enforcement:** Overseer explicitly checks each documented system touched by a Phase for doc accuracy as a required step in Phase review.
- **Exceptions:** None.

---

### L19 — Phase Completion Requires Docs Reconciliation

- **Rule:** A Phase MUST NOT be declared GREEN/complete until all documentation in `.ushabti/docs/` is reconciled with the code work performed in that Phase. This is a hard gate, not an advisory.
- **Rationale:** This law makes docs reconciliation a first-class completion criterion, ensuring it cannot be deferred or skipped.
- **Enforcement:** Overseer treats any unreconciled doc as a blocking defect equivalent to a failing test. The Phase remains open until docs are updated.
- **Exceptions:** None.

---

### L20 — Overseer Must Bump Build Number Before Approving Phase Completion

- **Rule:** Overseer MUST increment both `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` in `TakeNote.xcodeproj/project.pbxproj` before marking any Phase GREEN/complete. All four occurrences of each field (Debug and Release configurations for the TakeNote and NewNoteControl targets) MUST be updated to the same new value.
- **Version arithmetic:** `CURRENT_PROJECT_VERSION` is an integer; increment by 1 each Phase. `MARKETING_VERSION` is a three-part string (`major.minor.patch`); increment the patch number by 1 each Phase. When patch reaches 99, reset patch to 1 and increment minor (e.g., `1.1.99` → `1.2.1`). When minor reaches 99, reset minor and patch to 0.1 and increment major (e.g., `1.99.99` → `2.0.1`).
- **Rationale:** Every completed Phase must produce a uniquely identifiable, publishable build. Automating both increments as a Phase-gate obligation removes version management as a manual concern for the developer.
- **Enforcement:** Overseer searches `TakeNote.xcodeproj/project.pbxproj` for all occurrences of `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` and confirms each is set to the correctly incremented value. A Phase with unchanged version numbers MUST NOT be marked complete.
- **Scope:** `TakeNote.xcodeproj/project.pbxproj` — all four `CURRENT_PROJECT_VERSION` entries and all four `MARKETING_VERSION` entries.
- **Exceptions:** If a Phase produces no shippable change (e.g., a documentation-only or tooling-only Phase where no app binary is produced), the version increment may be skipped, but Overseer MUST explicitly note the exemption in the Phase review.
