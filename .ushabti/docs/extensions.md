# Extensions and Intents

## Overview

TakeNote extends beyond the main app with widgets, control center controls, and Siri/Shortcuts integration via App Intents.

## Widget Extension (NewNoteControl)

**Location:** `/NewNoteControl/`

Provides home screen widgets and Control Center controls.

### Bundle Structure

```swift
// TakeNoteBundle.swift
@main
struct TakeNoteBundle: WidgetBundle {
    var body: some Widget {
        NewNoteControl()   // Control Center control
        InboxWidget()      // Home screen widget
        StarredWidget()    // Home screen widget
    }
}
```

### InboxWidget

**File:** `/NewNoteControl/Widgets/InboxWidget.swift`

Displays recently updated notes from the Inbox folder.

```swift
struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.adamdrew.takenote.inboxWidget",
            provider: ContainerProvider<InboxSpec>()
        ) { entry in
            NoteContainerWidgetView(entry: entry, showNewButton: true)
        }
        .configurationDisplayName("Inbox")
        .description("Recently updated notes from your TakeNote Inbox.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### StarredWidget

**File:** `/NewNoteControl/Widgets/StarredWidget.swift`

Displays starred/favorited notes.

Similar structure to InboxWidget but uses `StarredSpec` to select the Starred container.

### ContainerSpec Protocol

Abstraction for selecting which container to display:

```swift
protocol ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot?
    static var placeholderSymbol: String { get }
    static var placeholderName: String { get }
}

struct InboxSpec: ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot? {
        snapshot.containers.first(where: { $0.isInbox })
    }
    static let placeholderSymbol = "tray.full"
    static let placeholderName = "Inbox"
}
```

### ContainerProvider

**File:** `/NewNoteControl/Library/ContainerProvider.swift`

TimelineProvider that fetches data from SwiftData for widget display.

Uses lightweight snapshots instead of full models to avoid SwiftData/widget conflicts.

### NoteContainerWidgetView

**File:** `/NewNoteControl/Views/NoteContainerWidgetView.swift`

Shared view for both widgets:
- Container header with icon and name
- List of recent notes with titles
- Optional "New Note" button
- Adapts layout to widget size family

### NewNoteControl

**File:** `/NewNoteControl/Controls/NewNoteControl.swift`

Control Center control for quickly creating a new note.

```swift
struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.adamdrew.takenote.newNote") {
            ControlWidgetButton(action: NewNoteIntent()) {
                Label("New Note", systemImage: "note.text.badge.plus")
            }
        }
        .displayName("New TakeNote")
        .description("Quickly create a new note.")
    }
}
```

## App Intents

**Location:** `/TakeNote/AppIntents/`

Siri and Shortcuts integration.

### NewNoteIntent

**File:** `/TakeNote/AppIntents/NewNoteIntent.swift`

Creates a new note in the Inbox and opens the app.

```swift
struct NewNoteIntent: AppIntent {
    @Dependency(key: "ModelContainer")
    private var modelContainer: ModelContainer
    @Dependency(key: "TakeNoteVM")
    private var takeNoteVM: TakeNoteVM

    static var title: LocalizedStringResource = "Create a new note"
    static var description = IntentDescription("Opens TakeNote and creates a new note in the Inbox.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        takeNoteVM.selectedContainer = takeNoteVM.inboxFolder
        let note = takeNoteVM.addNote(modelContainer.mainContext)
        if let note {
            takeNoteVM.openNote = note
            takeNoteVM.selectedNotes = [note]
        }
        return .result()
    }
}
```

### NewNoteWithContentIntent

**File:** `/TakeNote/AppIntents/NewNoteWithContentIntent.swift`

Creates a new note with pre-filled content (from Shortcuts or share sheet).

### Dependency Registration

Intents access app state via `AppDependencyManager`:

```swift
// In TakeNoteApp.init()
AppDependencyManager.shared.add(
    key: "ModelContainer",
    dependency: { @MainActor in modelContainer }
)
AppDependencyManager.shared.add(
    key: "TakeNoteVM",
    dependency: { @MainActor in viewModel }
)
```

## Share Extension (TakeNoteShare)

**Location:** `/TakeNoteShare/`

Minimal share extension structure exists but appears incomplete:
- Only contains `Base.lproj/` directory with storyboard
- No Swift implementation files observed

### Potential Purpose

Would allow sharing text/URLs from other apps directly into TakeNote as new notes.

## Entitlements

**File:** `/NewNoteControlExtension.entitlements`

Widget/control extension entitlements for:
- App Groups (shared container access)
- CloudKit (if needed for widget data)

## Widget Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Main App (TakeNote)                      │
│                                                             │
│  Note changes → WidgetCenter.shared.reloadAllTimelines()    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Widget Extension (NewNoteControl)           │
│                                                             │
│  ContainerProvider.getTimeline() → fetch from SwiftData     │
│  → Create lightweight snapshots                              │
│  → Return TimelineEntry                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Widget View Rendered                         │
│                                                             │
│  NoteContainerWidgetView displays notes                     │
│  Tapping opens app via deep link                            │
└─────────────────────────────────────────────────────────────┘
```

## Deep Link Integration

Widgets and intents use the `takenote://` URL scheme:
- `takenote://note/{uuid}` - Open specific note
- Handled by `.onOpenURL` in MainWindow
