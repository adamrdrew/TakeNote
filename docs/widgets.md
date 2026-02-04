# Widgets

TakeNote includes home screen widgets, lock screen widgets, and Control Center controls.

## Architecture

**Target:** `NewNoteControl/`

Widgets cannot directly access SwiftData. Instead:
1. Main app writes snapshots to app group container
2. Widgets read snapshots for display
3. Deep links open notes in main app

## Snapshot System

**File:** `SnapshotController.swift` (main app)

### Data Structures

```swift
struct ContainerSnapshot: Codable {
    let id: UUID
    let name: String
    let symbol: String
    let notes: [NoteSnapshot]
}

struct NoteSnapshot: Codable {
    let id: UUID
    let title: String
    let content: String  // Truncated ~200 chars
    let updatedDate: Date
}
```

### Snapshot Timing

Snapshots taken:
- On app launch/foreground
- Every 10 minutes while active
- On background transition

```swift
// TakeNoteApp.swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active:
        SnapshotController.takeSnapshot(modelContext: ctx)
        startActiveRefreshLoop(ctx: ctx)
    case .inactive, .background:
        SnapshotController.takeSnapshot(modelContext: ctx)
    }
}
```

### Storage Location

App group container: `group.com.adamdrew.takenote/snapshot.json`

### Contents

- All non-buffer containers
- 5 most recent notes per container
- Note content truncated to ~200 characters

## Timeline Provider

**File:** `ContainerProvider.swift`

Generic provider using `ContainerSpec` protocol:

```swift
protocol ContainerSpec {
    static func select(from containers: [ContainerSnapshot]) -> ContainerSnapshot?
}

struct InboxSpec: ContainerSpec {
    static func select(from containers: [ContainerSnapshot]) -> ContainerSnapshot? {
        containers.first { $0.name == "Inbox" }
    }
}

struct StarredSpec: ContainerSpec {
    static func select(from containers: [ContainerSnapshot]) -> ContainerSnapshot? {
        containers.first { $0.name == "Starred" }
    }
}
```

### Refresh Policy

```swift
func timeline(for configuration: ConfigurationAppIntent) async -> Timeline<NoteListEntry> {
    let entries = [NoteListEntry(date: .now, container: container)]

    let refreshDate: Date
    if container?.notes.isEmpty ?? true {
        refreshDate = .now.addingTimeInterval(45)  // 45 seconds if empty
    } else {
        refreshDate = .now.addingTimeInterval(600)  // 10 minutes if populated
    }

    return Timeline(entries: entries, policy: .after(refreshDate))
}
```

## Widgets

### Inbox Widget

**File:** `InboxWidget.swift`

Shows recent notes from Inbox with "New Note" button.

```swift
struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "InboxWidget",
            intent: ConfigurationAppIntent.self,
            provider: ContainerProvider<InboxSpec>()
        ) { entry in
            NoteContainerWidgetView(entry: entry, showNewNoteButton: true)
        }
        .configurationDisplayName("Inbox")
        .description("Recent notes from your Inbox")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### Starred Widget

**File:** `StarredWidget.swift`

Shows starred notes (no "New Note" button).

```swift
struct StarredWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "StarredWidget",
            intent: ConfigurationAppIntent.self,
            provider: ContainerProvider<StarredSpec>()
        ) { entry in
            NoteContainerWidgetView(entry: entry, showNewNoteButton: false)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

## Widget View

**File:** `NoteContainerWidgetView.swift`

### Size Variations

| Size | Notes Shown | Content |
|------|-------------|---------|
| Small | 4 | Titles only |
| Medium | 3 | Title + excerpt |
| Large | 5 | Title + excerpt |

### Deep Links

Each note links to `takenote://note/{uuid}`:

```swift
Link(destination: URL(string: "takenote://note/\(note.id)")!) {
    NoteRow(note: note)
}
```

### Empty State

Shows placeholder when no notes:

```swift
if container.notes.isEmpty {
    Text("No notes yet")
        .foregroundStyle(.secondary)
}
```

## Control Center Control

**File:** `NewNoteControl.swift`

Quick action to create new note:

```swift
struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewNoteControl") {
            ControlWidgetButton(action: NewNoteIntent()) {
                Label("New Note", systemImage: "square.and.pencil")
            }
        }
        .displayName("New Note")
        .description("Create a new note in TakeNote")
    }
}
```

Triggers `NewNoteIntent` which creates a note and opens the app.

## Widget Bundle

**File:** `TakeNoteBundle.swift`

```swift
@main
struct TakeNoteBundle: WidgetBundle {
    var body: some Widget {
        InboxWidget()
        StarredWidget()
        NewNoteControl()
    }
}
```

## Timeline Entry

**File:** `NoteListEntry.swift`

```swift
struct NoteListEntry: TimelineEntry {
    let date: Date
    let container: ContainerSnapshot?
}
```

## App Group Configuration

**Entitlements:** `NewNoteControlExtension.entitlements`

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.adamdrew.takenote</string>
</array>
```

Both main app and widget extension must have same app group to share snapshot file.

## Widget Reload

Widgets reloaded when notes change:

```swift
// Note.swift
func setContent(_ newContent: String) {
    self.content = newContent
    self.updatedDate = Date()
    WidgetCenter.shared.reloadAllTimelines()
}
```

Called from all Note setters: `setTitle()`, `setContent()`, `setFolder()`, `setTag()`.
