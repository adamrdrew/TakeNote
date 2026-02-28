# Vizier Memory

## Project Context

TakeNote is a multi-platform (macOS, iOS, visionOS) notes app built with SwiftUI and SwiftData, backed by CloudKit sync. It features on-device AI via Apple FoundationModels (Apple Intelligence), a RAG-based chat feature, and a widget extension.

Key files:
- Entry point: `/Users/adam/Development/TakeNote/TakeNote/TakeNoteApp.swift`
- Central state: `/Users/adam/Development/TakeNote/TakeNote/TakeNoteVM.swift`
- Models: `/Users/adam/Development/TakeNote/TakeNote/Models/` (Note, NoteContainer, NoteLink)
- Library: `/Users/adam/Development/TakeNote/TakeNote/Library/`
- Widget: `/Users/adam/Development/TakeNote/NewNoteControl/`
- Laws: `/Users/adam/Development/TakeNote/.ushabti/laws.md`
- Style: `/Users/adam/Development/TakeNote/.ushabti/style.md`
- Docs: `/Users/adam/Development/TakeNote/.ushabti/docs/`

## Architecture Summary

- `TakeNoteVM` is `@Observable @MainActor`, shared via SwiftUI environment
- SwiftData with CloudKit (`iCloud.com.adamdrew.takenote`), three @Model types: Note, NoteContainer, NoteLink
- `SearchIndexService` wraps `SearchIndex` (FTS5/SQLite) for RAG search; `VectorSearchIndex` exists but is NOT wired into production
- `MagicFormatter` for inline AI formatting; `ChatWindow` for Magic Chat (feature-flagged)
- `CommandRegistry` pattern for menu bar bridging to list items
- Widget reads data only via `SnapshotController.readSnapshot()` (App Group snapshot)
- `SystemFolderReconciler` merges CloudKit-induced duplicate system containers
- `AppDependencyManager` used by AppIntents to access TakeNoteVM and ModelContainer

## CloudKit Schema Management Workflow (critical context)

`ckBootstrapVersionCurrent` is intentionally inside `#if DEBUG`. This is correct behavior, not a violation. Schema changes are a development-time concern:

1. Developer bumps `ckBootstrapVersionCurrent` in DEBUG build
2. On next DEBUG launch, `bootstrapDevSchemaIfNeeded()` pushes the schema to the CloudKit development environment using `NSPersistentCloudKitContainer.initializeCloudKitSchema()`
3. Developer then manually promotes the schema to the production CloudKit container via the Apple CloudKit Dashboard
4. Production builds never need this code path — CloudKit schema is already live before the app ships

Any agent seeing `#if DEBUG` around `ckBootstrapVersionCurrent` must NOT flag it as a violation. It is the correct implementation of L03.

## `installReconciler` — actual default behavior

In `TakeNoteApp.init()`, `installReconciler` is called with `listenForLocalSaves: true` (not the default `false`). The doc says "not enabled by default" which is technically accurate about the parameter default, but the actual app call passes `true`. This means the reconciler runs on BOTH remote changes AND local saves in production.

## Known Issues / Technical Debt (verified audit Feb 2026)

### Law Violations (must fix)

- R001: `SearchIndexService.logger` has typo in subsystem: `com.adammdrew.takenote` (double 'm') — Style violation (wrong subsystem string)
- R002: `MagicFormatter` uses `ObservableObject`/`@Published` instead of `@Observable` — L09/Style violation
- R005: `NewNoteWithContentIntent.perform()` sets `note.content` and `note.title` directly, bypassing `setContent()`/`setTitle()` — Style/contract violation
- R007: `NoteEditor.doMagicFormat()` sets `openNote!.content` directly (line 160); CodeEditor binding also sets `openNote?.content` directly (line 232) bypassing `setContent()` — Style/contract violation
- R009: `NoteList.pasteNote()` sets multiple fields directly on a copy-paste new note, bypassing mutating methods
- R012: `NoteEditor` creates a new `NoteLinkManager(modelContext:)` inline on onChange — not a registry or environment object

### Confirmed Non-violations

- R003: `NoteEditorWindow` and `ChatWindow` creating `TakeNoteVM()` instances — intentional per L09 exception
- R004 RESOLVED: `ChatWindow.generateResponse()` DOES have an availability guard at line 118: `guard SystemLanguageModel.default.availability == .available else { ... }` — compliant with L05
- R008: `ckBootstrapVersionCurrent` inside `#if DEBUG` is intentional — see CloudKit Schema Management Workflow above
- L01: Deployment targets are macOS 26 and iOS 26 — confirmed compliant
- L02/L03: Only Note, NoteContainer, NoteLink are `@Model` types — confirmed
- L04: No third-party LLM imports — confirmed
- L06: `MagicFormatter` reassigns session to a fresh instance at the start of every `magicFormat()` call — compliant per style guide exception
- L07: Chat surfaces all gated on `chatFeatureFlagEnabled` — confirmed
- L08: Widget code uses only `SnapshotController.readSnapshot()` — confirmed
- L11: System containers consistently created with `canBeDeleted: false`; reconciler wired to `NSPersistentStoreRemoteChange`
- L12: `Note.uuid` has `private(set)` — confirmed
- L13: `SearchIndexService.index` is `SearchIndex` (FTS5) — confirmed
- L14: Both AppIntents use `@Dependency(key:)` correctly
- L15: List entries have matching onAppear/onDisappear register/unregister pairs

### Style Violations (should fix)

- R006: Production `print()` calls outside `#if DEBUG` in TakeNoteVM, CommandRegistry, SystemFolderReconciler, NoteLinkManager, EditCommands
- R013: Direct property sets bypassing model mutating methods in several places (NoteList cut/paste, NoteEditor content set)

## Key Doc Inaccuracies (audit Feb 2026)

Major findings from documentation audit:

1. **architecture.md**: Missing the complete CloudKit schema management workflow explanation (why `#if DEBUG` is correct). The doc mentions the two-step protocol but does NOT explain that production schema promotion happens via Apple's CloudKit Dashboard, not code. This gap caused R008 misunderstanding.

2. **architecture.md**: `installReconciler` is called with `listenForLocalSaves: true` in TakeNoteApp but the doc says this is "not enabled by default" without noting it IS enabled in practice.

3. **ai-features.md**: `MagicFormatter` is documented as `@MainActor, ObservableObject` but the doc omits that it uses `@Published` (not `@Observable`) — this is a discrepancy from the style guide's requirement to use `@Observable`.

4. **ai-features.md**: `isAvailable` property described as `languageModel.isAvailable` — but `SystemLanguageModel` doesn't have `.isAvailable`; the actual property is `languageModel.availability == .available`. The AI Features doc description of `isAvailable` property is inconsistent with how availability is checked in `TakeNoteVM.aiIsAvailable`.

5. **ai-features.md**: L05 gap in docs — docs do not clearly document the availability check in `ChatWindow.generateResponse()`. The check is present in code but the doc's description does not match it closely.

6. **search-system.md**: `searchNatural` is documented as joining tokens with `AND` but the comment in the source says "join with OR". The actual code joins with `AND` (line 218 of SearchIndex.swift). The doc text matches the code but the comment inside the source is misleading.

7. **data-models.md**: `Note.title` defaults to `"New Note"` per the doc, but in code the actual default property is `""` and `defaultTitle = "New Note"` is a separate field. The initializer sets `self.title = self.defaultTitle`.

8. **supporting-systems.md**: `AppBootstrapper.makeModelConfiguration` doc says "In DEBUG builds, uses a file at `~/Library/Application Support/TakeNoteDev/TakeNote.sqlite`" — this is accurate but incomplete: the URL is constructed by `TakeNoteApp.debugStoreURL()` and passed in, not hardcoded inside `makeModelConfiguration`.

9. **views.md**: `NoteListHeader` description says "Content unknown beyond filename — not read in detail during survey" — this is a gap left from the survey phase, not updated.

10. **views.md**: `ChatWindow` Chat toolbar button — doc says it is "Gated by `chatFeatureFlagEnabled`" which is true, but the actual gate in `MainWindow` is `chatFeatureFlagEnabled && chatEnabled` where `chatEnabled = takeNoteVM.aiIsAvailable && notes.count > 0`. The button requires both the feature flag AND AI availability AND notes to exist.

## FoundationModels Streaming API

`LanguageModelSession.streamResponse(to:)` returns a `ResponseStream` conforming to `AsyncSequence`. For plain `String` generation, each iteration element is a partial string snapshot. Usage pattern:

```swift
let stream = session.streamResponse(to: prompt)
for try await partial in stream {
    // partial is a String snapshot growing with each token
    currentText = partial
}
```

This is distinct from `session.respond(to:)` which awaits the complete response. The streaming variant enables progressive UI updates. The final complete value is available after the loop ends (or via `stream.collect()`). Each intermediate `partial` is a full snapshot, not a delta — so assigning `@State` directly to each yields the progressive build-up.

## Note URL Scheme

`Note.getURL()` returns `"takenote://note/<UUID>"`. This is the deep link format used throughout the app. `TakeNoteVM.loadNoteFromURL()` handles these URLs in `MainWindow.onOpenURL`. The URL derives from `note.uuid.uuidString`. `Note.getMarkdownLink()` returns `"[<title>](takenote://note/<UUID>)"`.

## ChatWindow — No ModelContext

`ChatWindow` does not currently have `@Query` or `@Environment(\.modelContext)`. To look up notes from `SearchHit.noteID` (UUID) values for citation purposes, a `@Query() var notes: [Note]` must be added. The note title can then be fetched by matching UUID: `notes.first(where: { $0.uuid == hit.noteID })`.

## User Preferences

None recorded yet.

## Reference Library

### Languages
- [Swift Documentation](https://www.swift.org/documentation/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

### Frameworks
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [FoundationModels Documentation](https://developer.apple.com/documentation/foundationmodels)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [AppIntents Documentation](https://developer.apple.com/documentation/appintents)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)

### Libraries
- [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- [CodeEditorView](https://github.com/mchakravarty/CodeEditorView)
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

### Tools
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
