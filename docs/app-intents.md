# App Intents

TakeNote supports Siri shortcuts and system integrations via App Intents.

## Overview

**Directory:** `TakeNote/AppIntents/`

App Intents enable:
- Siri voice commands
- Shortcuts app integration
- Control Center widgets
- Spotlight suggestions

## Available Intents

### NewNoteIntent

**File:** `NewNoteIntent.swift`

Creates an empty note in the Inbox.

```swift
struct NewNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "New Note"
    static var description = IntentDescription("Creates a new note in TakeNote")

    @Dependency(key: "ModelContainer")
    var containerProvider: () async -> ModelContainer

    @Dependency(key: "TakeNoteVM")
    var vmProvider: () async -> TakeNoteVM

    func perform() async throws -> some IntentResult {
        let container = await containerProvider()
        let vm = await vmProvider()

        let context = ModelContext(container)

        // Ensure inbox exists
        vm.folderInit(context)

        // Create note
        let note = vm.addNote(context)

        return .result()
    }

    static var openAppWhenRun: Bool = true
}
```

### NewNoteWithContentIntent

**File:** `NewNoteWithContentIntent.swift`

Creates a note with specified title and content.

```swift
struct NewNoteWithContentIntent: AppIntent {
    static var title: LocalizedStringResource = "New Note with Content"

    @Parameter(title: "Title")
    var noteTitle: String

    @Parameter(title: "Content")
    var noteContent: String

    func perform() async throws -> some IntentResult {
        // Similar to NewNoteIntent, but sets title and content
        let note = vm.addNote(context)
        note?.setTitle(noteTitle)
        note?.setContent(noteContent)

        return .result()
    }

    static var openAppWhenRun: Bool = true
}
```

## Dependency Injection

**File:** `TakeNoteApp.swift`

App Intents can't directly access the app's ModelContainer or ViewModel. Dependencies are registered at app startup:

```swift
// Capture values in locals
let modelContainer = container
let viewModel = takeNoteVM

// Register ModelContainer dependency
let asyncModelContainerDep: @Sendable () async -> ModelContainer = {
    @MainActor in
    return modelContainer
}
AppDependencyManager.shared.add(
    key: "ModelContainer",
    dependency: asyncModelContainerDep
)

// Register ViewModel dependency
let asyncViewModelDep: @Sendable () async -> TakeNoteVM = {
    @MainActor in
    return viewModel
}
AppDependencyManager.shared.add(
    key: "TakeNoteVM",
    dependency: asyncViewModelDep
)
```

### Usage in Intents

```swift
@Dependency(key: "ModelContainer")
var containerProvider: () async -> ModelContainer

// In perform():
let container = await containerProvider()
```

## Main Actor Requirement

Both dependencies use `@MainActor` closures because:
- SwiftData requires main actor for ModelContext operations
- TakeNoteVM is `@MainActor`

```swift
let asyncModelContainerDep: @Sendable () async -> ModelContainer = {
    @MainActor in  // Ensures main actor execution
    return modelContainer
}
```

## Control Center Integration

**File:** `NewNoteControl/Controls/NewNoteControl.swift`

Control Center widget uses `NewNoteIntent`:

```swift
struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewNoteControl") {
            ControlWidgetButton(action: NewNoteIntent()) {
                Label("New Note", systemImage: "square.and.pencil")
            }
        }
    }
}
```

## Shortcuts App

Both intents appear in the Shortcuts app:
- "New Note" - Creates empty note
- "New Note with Content" - Creates note with parameters

Users can:
- Add to home screen
- Trigger via Siri
- Include in automation workflows
- Chain with other shortcuts

## Siri Phrases

Example voice commands:
- "Hey Siri, create a new note in TakeNote"
- "Hey Siri, new TakeNote note"

The system learns from app metadata and intent titles.

## Open App Behavior

Both intents set `openAppWhenRun = true`:

```swift
static var openAppWhenRun: Bool = true
```

This ensures:
- App launches after intent execution
- User sees the newly created note
- Full app context available for editing
