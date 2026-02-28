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
- SPM dependencies: CodeEditorView 0.15.4, swift-markdown-ui 2.4.1, SQLite.swift 0.15.4, NetworkImage 6.0.1, SFSymbolsPicker 1.0.7

## CloudKit Schema Management Workflow (critical context)

`ckBootstrapVersionCurrent` is intentionally inside `#if DEBUG`. This is correct behavior, not a violation. Schema changes are a development-time concern:

1. Developer bumps `ckBootstrapVersionCurrent` in DEBUG build
2. On next DEBUG launch, `bootstrapDevSchemaIfNeeded()` pushes the schema to the CloudKit development environment using `NSPersistentCloudKitContainer.initializeCloudKitSchema()`
3. Developer then manually promotes the schema from development to production CloudKit container via the Apple CloudKit Dashboard
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

### Magic Assistant Bug — R014 (Phase 0013 regression, current state on branch `magic-chat-improvements`)

**Status:** The fix attempt on this branch introduced a new bug. `makePrompt()` now does branch on `prompt` (the fix was partially applied), but `conversation.last?.text` returns the WRONG entry because `generateResponse()` appends a blank bot entry to `conversation` BEFORE calling `makePrompt()`. So `conversation.last` is the bot's empty `""` entry, not the user's message.

**Exact execution order in `generateResponse()` (current branch code):**
1. `conversation.append(botEntry)` — bot's blank entry is now `.last`
2. `let assembledPrompt = makePrompt()` — calls `conversation.last?.text` which is now `""`
3. Sends empty user request to LLM

**What `makePrompt()` builds for Magic Assistant (with `prompt = "USER_REQUEST:\n"`):**
```
USER_REQUEST:
                          ← empty because conversation.last is the bot entry
CONTEXT:
<selectedText>

```
The user's actual request ("make this bold", "make this a link") is completely absent.

**Why the old code (`session.respond(to:)`) worked:** In the master version, `generateResponse()` called `makePrompt()` FIRST, then appended the bot response entry after receiving it. So `conversation.last` was still the user's message when `makePrompt()` ran.

**The two-part fix needed:**
1. Call `makePrompt()` BEFORE appending the bot entry (capture the prompt string first)
2. OR change `makePrompt()` to look for the last `.human` sender entry, not just `.last`

**Note on `respond` vs `streamResponse` parameter types:** Both accept `Swift.String` directly (`@_disfavoredOverload`). The API difference is not the root cause of this bug. The type is the same.

### Confirmed Non-violations

- R003: `NoteEditorWindow` and `ChatWindow` creating `TakeNoteVM()` instances — intentional per L09 exception
- R004 RESOLVED: `ChatWindow.generateResponse()` DOES have an availability guard — compliant with L05
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

## Images-in-Notes Feature (planned, Phase 0011+)

Design spike completed Feb 2026. Key architectural decisions:
- New `@Model` class `NoteImage` required (law L02 update needed)
- Images stored as `Data` (binary) in SwiftData — base64 is unnecessary overhead since SwiftData/CloudKit handles binary natively
- UUID field on `NoteImage` is stable cross-device identifier
- URL scheme: `takenote://image/<UUID>` (new handler alongside existing `takenote://note/<UUID>`)
- Markdown references: `![alt](takenote://image/<UUID>)`
- MarkdownUI 2.4.1 supports custom image providers via `.markdownImageProvider()`
- Orphan culling: scan `NoteImage` records and check if any Note.content contains their UUID
- Image picker: `PhotosPickerItem` (PhotosUI framework) — no new entitlements needed for standard photo picker
- Drag and drop: `.dropDestination(for: Data.self)` or `for: URL.self` with image UTType filtering

## Key Doc Inaccuracies (audit Feb 2026)

Major findings from documentation audit — recorded previously, still unresolved.

## FoundationModels Streaming API

`LanguageModelSession.streamResponse(to:)` returns a `ResponseStream` conforming to `AsyncSequence`. For plain `String` generation, each iteration element is a partial string snapshot. Usage pattern:

```swift
let stream = session.streamResponse(to: prompt)
for try await partial in stream {
    // partial is a String snapshot growing with each token
    currentText = partial
}
```

This is distinct from `session.respond(to:)` which awaits the complete response. The streaming variant enables progressive UI updates. Both accept `Swift.String` directly.

## Note URL Scheme

`Note.getURL()` returns `"takenote://note/<UUID>"`. This is the deep link format used throughout the app. `Note.getMarkdownLink()` returns `"[<title>](takenote://note/<UUID>)"`.

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
- [PhotosUI Documentation](https://developer.apple.com/documentation/photosuit)

### Libraries
- [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- [CodeEditorView](https://github.com/mchakravarty/CodeEditorView)
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

### Tools
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
