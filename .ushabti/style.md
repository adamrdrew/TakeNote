# Project Style Guide

## Purpose

This guide documents the conventions already established in the TakeNote codebase. It is the reference for anyone writing new code or reviewing existing code. It does not introduce new patterns; it captures what is already in practice.

Laws (`.ushabti/laws.md`) take precedence over this guide in every case of conflict.

---

## Project Structure

```
TakeNote/                  # Main app target
├── TakeNoteApp.swift      # Entry point, scene composition, app-wide wiring
├── TakeNoteVM.swift       # Central state manager
├── Models/                # SwiftData @Model classes only
│   ├── Note.swift
│   ├── NoteContainer.swift
│   └── NoteLink.swift
├── Views/                 # All SwiftUI views, grouped by screen/feature
│   ├── MainWindow/        # Root window and Sidebar
│   ├── NoteList/          # Note list column and row views
│   ├── NoteEditor/        # Detail editor and backlinks views
│   ├── ChatWindow/        # AI chat interface
│   ├── FolderList/        # Folder row components
│   ├── TagList/           # Tag row components
│   ├── Commands/          # SwiftUI Commands structs (menu bar)
│   ├── Helpers/           # Shared small views (AIMessage, etc.)
│   └── WelcomeMessage/    # Onboarding screen
├── Library/               # Services, utilities, and non-view logic
│   ├── CommandRegistry.swift
│   ├── SearchIndex.swift
│   ├── SearchIndexService.swift
│   ├── MagicFormatter.swift
│   ├── AppBootstrapper.swift
│   ├── SystemFolderReconciler.swift
│   ├── SnapshotController.swift
│   ├── NoteLinkManager.swift
│   ├── FileImport.swift
│   ├── FocusValues.swift
│   └── ... (other utilities)
├── Prompts/               # LLM prompt string constants
├── AppIntents/            # Siri / Shortcuts intents
└── Assets.xcassets/

NewNoteControl/            # Widget extension target
TakeNoteShare/             # Share extension target (currently empty)
```

**Rules:**

- `Models/` contains only SwiftData `@Model` classes. No view code or service logic belongs there.
- `Library/` contains services and utilities that are not SwiftUI views. Services that hold observable state go here, not in `Models/` or `Views/`.
- `Views/` subdirectories are named for the screen or feature column they represent. A subdirectory contains both the primary `List`/container view and its child entry view.
- `Prompts/` contains only prompt string constants, one file per AI feature. No logic belongs there.
- Widget-only code lives in `NewNoteControl/`, not in the main target. Widget code never accesses `ModelContainer` directly (see L08).

---

## Language and Tooling Conventions

- **Language:** Swift 6, strict concurrency.
- **Minimum targets:** macOS 26, iOS 26 (see L01). No `#available` checks for earlier versions.
- **Build system:** Xcode with a standard `.xcodeproj`. No SPM-managed app manifest.
- **Dependencies (SPM):**
  - `CodeEditorView` — code editor with syntax highlighting
  - `MarkdownUI` — rendered Markdown display
  - `SQLite.swift` — FTS5 search index
- **Logging:** Use `os.Logger` with subsystem `com.adamdrew.takenote` and a per-file category string. Do not use `print()` in production code paths; `print()` is acceptable only for debug traces that will be removed.
- **Conditional compilation:** Use `#if os(macOS)`, `#if os(iOS)`, `#if os(visionOS)`, and `#if DEBUG` blocks. No platform-specific logic outside these guards.

---

## Architectural Patterns

### Preferred

#### TakeNoteVM as single state manager

`TakeNoteVM` is the one `@Observable @MainActor` class that holds app-wide state. It is instantiated once in `TakeNoteApp` and shared via `.environment(takeNoteVM)`. Every window that needs app state reads it with `@Environment(TakeNoteVM.self)`.

New app-scoped state belongs in `TakeNoteVM`, not in a new class. Legitimate exceptions are service objects that own narrowly scoped state (`SearchIndexService`, `NoteLinkManager`).

`NoteEditorWindow` creates its own `TakeNoteVM` instance intentionally for process isolation of the detached editor window. This is the only sanctioned deviation.

#### @Observable service objects

Service classes (`SearchIndexService`, `NoteLinkManager`) are `@Observable @MainActor`. They are injected into the SwiftUI environment alongside `TakeNoteVM` and accessed via `@Environment`. They are not global singletons.

#### SwiftUI view decomposition via computed `var` sub-views

Complex list row views break their layout into named computed `var` properties typed as `some View`. This avoids deeply nested closures and gives each row section a readable name.

Example pattern from `NoteListEntry`:

```swift
var TitleRow: some View { ... }
var MetadataRow: some View { ... }
var SummaryRow: some View { ... }

var body: some View {
    VStack(alignment: .leading, spacing: vSpacing) {
        TitleRow
        MetadataRow
        SummaryRow
    }
}
```

Sub-view properties on list entry types are named with `UpperCamelCase` (matching type-level naming) to distinguish them visually from local variable properties. This is the established convention; follow it for new entry views.

#### CommandRegistry for menu bar bridging

Any `List` item that must respond to menu bar commands uses the `CommandRegistry` pattern:

1. The parent `List` view owns `@State` `CommandRegistry` instances (one per command).
2. The parent injects them into the environment with a named `EnvironmentKey` and into `FocusedValues`.
3. The child list item (`onAppear`) calls `registry.registerCommand(id: item.persistentModelID, command: closure)`.
4. The child list item (`onDisappear`) calls `registry.unregisterCommand(id: item.persistentModelID)`.
5. The `Commands` struct reads the registry from `@FocusedValue` and calls `registry.runCommand(id: selectedItem.id)`.

Both `.onAppear` registration and `.onDisappear` unregistration are required. A one-sided registration is a defect (see L15).

Environment keys for `CommandRegistry` instances follow this naming convention:

```swift
private struct NoteDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
extension EnvironmentValues {
    var noteDeleteRegistry: CommandRegistry {
        get { self[NoteDeleteRegistryKey.self] }
        set { self[NoteDeleteRegistryKey.self] = newValue }
    }
}
```

The key struct is `private` and file-local. The `EnvironmentValues` extension is in the same file as the `List` that owns the registries.

`FocusedValues` entries use the `@Entry` macro:

```swift
extension FocusedValues {
    @Entry var noteDeleteRegistry: CommandRegistry?
}
```

`FocusedValues` extensions live in the file of the view that sets them (the `List`), not in a shared file.

#### AI availability gate before every LLM call

Every code path that creates a `LanguageModelSession` must check availability first. Use `TakeNoteVM.aiIsAvailable` at the view/service level, or `note.canGenerateAISummary()` at the model level.

Correct pattern:

```swift
if takeNoteVM.aiIsAvailable {
    // safe to proceed with LLM call
}
```

Incorrect — calling without a gate:

```swift
let session = LanguageModelSession(instructions: ...)
let response = try await session.respond(to: prompt)
```

#### Stateless LLM sessions

Create a fresh `LanguageModelSession` for each individual LLM response. Never store a session as a property that survives across calls. Build full conversation history into the prompt text instead of relying on session context.

```swift
// Correct: new session per response
let session = LanguageModelSession(instructions: instructions)
let response = try await session.respond(to: prompt)

// Incorrect: reusing a stored session
self.session = LanguageModelSession(...)  // stored property — do not do this
```

`MagicFormatter` is the one apparent exception: it stores a session property but reassigns it to a fresh `LanguageModelSession` at the start of every `magicFormat()` call. The stored property is never reused across calls; it is overwritten. This satisfies L06.

#### Feature flag checks for Magic Chat surfaces

The Magic Chat UI surfaces — the Chat window/popover and the Chat toolbar button — must check `chatFeatureFlagEnabled` before rendering or executing. Read the flag from the global computed variable in `ChatFeatureFlagEnabled.swift`.

FTS indexing (`SearchIndexService.reindex` and `reindexAll`) is unconditional and must NOT be gated on `chatFeatureFlagEnabled`. Note list search depends on FTS regardless of whether Magic Chat is enabled; the two concerns are independent (see L07).

#### AppIntents access state through AppDependencyManager

`AppIntent` implementations access `TakeNoteVM` and `ModelContainer` exclusively through `@Dependency(key:)`. They do not capture environment objects or hold direct references.

```swift
@Dependency(key: "ModelContainer") private var modelContainer: ModelContainer
@Dependency(key: "TakeNoteVM") private var takeNoteVM: TakeNoteVM
```

#### Widget data access through snapshot only

Widget code reads note data only through `SnapshotController.readSnapshot()`. No widget code may import or instantiate `ModelContainer` or any `@Model` type (see L08).

#### SwiftData model mutations go through model methods

Mutating `Note` fields that need side effects (updating `updatedDate`, triggering widget reloads) must go through the provided model methods (`setTitle(_:)`, `setContent(_:)`, `setFolder(_:)`, `setTag(_:)`) rather than direct property assignment. This keeps side-effect logic in one place.

#### Platform branching

Platform-specific behavior uses conditional compilation blocks, not runtime checks wherever the compiler can resolve it at build time. `UIDevice.current.userInterfaceIdiom` checks are acceptable inside `#if os(iOS)` blocks for phone-vs-iPad distinctions.

#### Error display pattern in TakeNoteVM

Operations on `TakeNoteVM` that can fail assign `errorAlertMessage` and set `errorAlertIsVisible = true`. Views bind to these properties to show the generic error alert. Do not show platform-specific alert APIs directly from `TakeNoteVM`.

### Discouraged / Forbidden

- **New `@Model` types** without updating L02 and L03. SwiftData models are a schema contract.
- **Direct `modelContext.delete(note)` outside `emptyTrash()`** (see L10). Notes are moved to Trash; permanent deletion only happens via `emptyTrash()`.
- **Storing a `LanguageModelSession` as a surviving property** to be reused across calls (see L06).
- **Any `#available` check for a version below macOS 26 / iOS 26** (see L01).
- **New app-wide `@Observable` or `ObservableObject` state managers** that duplicate `TakeNoteVM`'s role (see L09).
- **Widget code touching `ModelContainer` directly** (see L08).
- **Wiring `VectorSearchIndex` into `SearchIndexService`** without a deliberate decision recorded in laws (see L13).
- **New chat entry points not gated on `chatFeatureFlagEnabled`** (see L07).
- **LLM calls without an availability check** (see L05).
- **`NSPersistentStoreRemoteChange` listener added without triggering `SystemFolderReconciler.runOnce()`** — the reconciler must run on every remote change.

---

## Naming Conventions

### Types

- `UpperCamelCase` for all types: `TakeNoteVM`, `NoteListEntry`, `CommandRegistry`, `SearchIndexService`, `MagicFormatter`, `NoteIDWrapper`.
- View types are named for what they display: `NoteList`, `NoteListEntry`, `FolderListEntry`, `NoteEditor`.
- Service types are named for what they do: `SearchIndexService`, `NoteLinkManager`, `SnapshotController`, `SystemFolderReconciler`, `AppBootstrapper`.
- `Commands` structs follow the pattern `<Domain>Commands`: `FileCommands`, `EditCommands`, `ViewCommands`, `WindowCommands`.
- `EnvironmentKey` key structs use the pattern `<PropertyName>Key` and are `private`.

### Properties and Methods

- `lowerCamelCase` for all properties and methods.
- Boolean state flags that describe an active mode or condition use the `inXxxMode` pattern: `inRenameMode`, `inMoveToTrashMode`, `inDeleteMode`.
- Boolean flags that control alert or popover visibility use `xIsPresented`, `showX`, or `xIsVisible`: `emptyTrashAlertIsPresented`, `showExportDialog`, `errorAlertIsVisible`.
- Boolean computed properties expressing capability use `canX`: `canAddNote`, `canEmptyTrash`, `canRenameSelectedContainer`.
- Boolean computed properties expressing existence use `xExists` or `xIsEmpty`: `inboxFolderExists`, `bufferIsEmpty`.
- Action methods that begin an operation use `startX`: `startRename`, `startDelete`.
- Action methods that complete an operation use `finishX` or `doX`: `finishRename`, `doMagicFormat`.
- Event-response methods use `onX`: `onNoteSelect`, `onMoveToFolder`, `onTagDelete`.
- Methods on models that expose data use `getX()`: `getURL()`, `getMarkdownLink()`, `getSystemImageName()`, `getColor()`.
- Methods that check feasibility use `canX()`: `canGenerateAISummary()`.

### Constants

- Module-level string and version constants are `lowerCamelCase` private `let` at file scope: `onboardingVersionCurrent`, `ckBootstrapVersionCurrent`.
- Prompt string constants are `SCREAMING_SNAKE_CASE` in `Prompts/`: `MAGIC_FORMAT_PROMPT`, `MAGIC_CHAT_PROMPT`, `MAGIC_FORMAT_FAILURE_TOKEN`.
- Static string constants on `TakeNoteVM` are `lowerCamelCase` `static let`: `inboxFolderName`, `trashFolderName`, `chatWindowID`.

### Files

- One primary type per file. The file name matches the primary type name: `NoteListEntry.swift` contains `NoteListEntry`.
- Supporting small types defined alongside a primary type stay in that file (e.g., `MovePopoverContent` in `NoteListEntry.swift`, `NoteIDWrapper` in `Note.swift`).

---

## SwiftData Model Conventions

- All `@Model` fields that are not persisted are marked `@Transient`. Transient fields do not require a schema version bump.
- All `@Relationship` declarations specify `deleteRule` explicitly. Do not rely on defaults.
- Persisted fields are all initialized with default values in the property declaration so SwiftData can hydrate them without the designated initializer.
- Model files begin with the `// Hey! // Hey you!` schema-change reminder comment.
- Model methods that mutate state call `WidgetCenter.shared.reloadAllTimelines()` as a side effect where appropriate.
- Schema changes require bumping `ckBootstrapVersionCurrent` in `TakeNoteApp.swift` (see L03).

---

## Testing Strategy

The codebase does not currently have a structured test target with unit tests visible in the survey. Until a testing approach is established, the following minimal expectations apply:

- `VectorSearchIndex` and debug-only code may be exercised in isolation in tests.
- `SearchIndex` (FTS5) must remain the production implementation wired into `SearchIndexService`; do not swap to `VectorSearchIndex` in tests that also exercise the service layer.
- Any new service or utility with testable pure logic should have unit tests in a test target.

---

## Error Handling and Observability

### Error handling in TakeNoteVM

`TakeNoteVM` methods that call `modelContext.save()` wrap it in `do/catch` and set `errorAlertMessage` + `errorAlertIsVisible` on failure. They do not `fatalError` on save failures in production. Use `try?` only for saves where silent failure is acceptable and documented.

### Logging

Use `os.Logger` for all persistent logging:

```swift
let logger = Logger(subsystem: "com.adamdrew.takenote", category: "ClassName")
logger.debug("...")   // verbose developer traces
logger.info("...")    // notable state changes
logger.warning("...")  // recoverable errors or unexpected conditions
logger.critical("...")  // logic violations (e.g., content hash mismatch)
```

The subsystem is always `com.adamdrew.takenote`. The category is the class name or feature area.

`print()` is used for transient debug output (`CommandRegistry.runCommand`, some `EditCommands` paths). These are acceptable as-is but should not be introduced in new code.

### AI error handling

`MagicFormatter.magicFormat()` returns a `MagicFormatterResult` struct rather than throwing. Callers check `result.didSucceed` and `result.wasCancelled` before applying the result. This pattern avoids try/catch at the call site and keeps cancellation handling explicit.

Fake-cancel is the established pattern for `LanguageModelSession` (which cannot be truly cancelled): set a flag before the `await`, check it after, and treat the resolved response as cancelled.

LLM model methods (`Note.generateSummary()`) swallow errors with `try?`. This is intentional: a summary failure is non-critical and should not surface an error to the user.

---

## Performance and Resource Use

- **Search index rate limiting:** `SearchIndexService.reindexAll()` is rate-limited to once per 10 minutes via `canReindexAllNotes()`. Do not call `reindexAll()` without going through this gate.
- **FTS indexing is always-on:** `reindex(note:)` and `reindexAll()` run unconditionally. Do not add a `chatFeatureFlagEnabled` guard to any indexing path (see L07).
- **Snapshot writes:** `SnapshotController.takeSnapshot()` runs on scene phase changes and every 10 minutes while active. New triggers should be justified; this is already frequent.
- **Widget reload:** `WidgetCenter.shared.reloadAllTimelines()` is called on every note mutation (in `Note` initializer and mutating methods). This is the existing pattern; do not add additional `reloadAllTimelines()` calls without good reason.
- **In-memory search index in DEBUG:** `SearchIndex` uses an in-memory connection in DEBUG builds. This is intentional and must be preserved so development builds do not leave stale on-disk search data.
- **Session prewarm:** `MagicFormatter.init()` calls `session.prewarm()`. New LLM service objects should consider prewarming if they are instantiated before their first use.

---

## Review Checklist

Reviewers verify each of these items for any pull request that touches the listed areas:

**SwiftData and persistence**
- [ ] No new `@Model` types introduced without law update (L02).
- [ ] Any field addition/removal/rename on `Note`, `NoteContainer`, or `NoteLink` is accompanied by a `ckBootstrapVersionCurrent` bump (L03).
- [ ] No `modelContext.delete(note)` call outside `TakeNoteVM.emptyTrash()` (L10).
- [ ] No system container has `canBeDeleted = true` (L11).
- [ ] `Note.uuid` is not reassigned after creation (L12).

**AI features**
- [ ] Every `LanguageModelSession` instantiation is guarded by `aiIsAvailable` or `canGenerateAISummary()` (L05).
- [ ] No `LanguageModelSession` instance is stored as a surviving property reused across calls (L06).
- [ ] No third-party LLM API calls or framework imports (L04).

**Magic Chat feature flag**
- [ ] Any new chat UI surface (Chat window/popover, Chat toolbar button) checks `chatFeatureFlagEnabled` (L07).
- [ ] No new `chatFeatureFlagEnabled` guard is added to any FTS indexing path; indexing must remain unconditional (L07).

**CommandRegistry**
- [ ] Any new list item that registers commands also unregisters them in `.onDisappear` (L15).
- [ ] New `CommandRegistry`-backed operations have corresponding `EnvironmentKey` and `FocusedValues` entries.

**State management**
- [ ] No new app-wide `@Observable` or `ObservableObject` introduced to manage state that belongs in `TakeNoteVM` (L09).
- [ ] `AppIntent` implementations access `TakeNoteVM` and `ModelContainer` only via `@Dependency(key:)` (L14).

**Widget**
- [ ] Widget code does not import or instantiate `ModelContainer`, `ModelContext`, or any `@Model` type (L08).

**Search**
- [ ] `SearchIndexService.index` remains of type `SearchIndex` (FTS5), not `VectorSearchIndex` (L13).

**Platform and deployment target**
- [ ] No `#available` check for a version below macOS 26 / iOS 26 (L01).

**General craft**
- [ ] New service objects use `os.Logger`, not `print()`.
- [ ] Model mutations that need side effects go through the model's mutating methods, not direct property writes.
- [ ] Sub-view computed properties on list entry types use `UpperCamelCase`.
- [ ] New `EnvironmentKey` key structs are `private` and file-local.
