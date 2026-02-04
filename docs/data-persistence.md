# Data Persistence

TakeNote uses SwiftData with CloudKit synchronization for cross-device sync.

## SwiftData Configuration

**File:** `TakeNoteApp.swift`

### Model Container Setup

```swift
container = try ModelContainer(
    for: Note.self,
    NoteContainer.self,
    NoteLink.self,
    configurations: config
)
```

### Store Location

**DEBUG builds:** `~/Library/Application Support/TakeNoteDev/TakeNote.sqlite`

**Release builds:** Default SwiftData location with CloudKit sync

## CloudKit Schema Management

### DEBUG Schema Bootstrap

**File:** `AppBootstrapper.swift`

In DEBUG builds, TakeNote manually pushes schema changes to CloudKit Development environment.

**Process:**
1. Check `ckBootstrapVersionKey` in UserDefaults
2. If version differs from `ckBootstrapVersionCurrent`, bootstrap needed
3. Create temporary NSPersistentCloudKitContainer
4. Call `initializeCloudKitSchema()` to push schema
5. Update UserDefaults version
6. Delete temporary store

**Version constants in `TakeNoteApp.swift`:**
```swift
#if DEBUG
    private let ckBootstrapVersionCurrent = 8
    private let ckBootstrapVersionKey = "takenote.ck.bootstrap.version"
#endif
```

**When to bump version:**
- Any change to `@Model` class properties
- Any change to relationships
- Any change to model attributes

### Error Handling

Bootstrap gracefully ignores expected CloudKit errors:
- Network errors (transient)
- Authentication errors (user not signed in)
- Rate limiting
- Partial failures

Only unexpected errors are logged as warnings.

## System Folder Reconciliation

**File:** `SystemFolderReconciler.swift`

CloudKit sync can create duplicate system folders when syncing between devices. The reconciler handles this.

### Reconciliation Process

1. Triggered by `NSPersistentStoreRemoteChange` notification
2. For each system folder type (Inbox, Trash, Buffer, Starred):
   - Fetch all matching containers
   - If duplicates exist, choose canonical (most notes, then lowest ID hash)
   - Move notes from duplicates to canonical
   - Delete duplicate containers
3. Update VM references to canonical containers
4. Enforce system folder color (`0xFF26B9FF`)

### Re-entrance Protection

```swift
private var isRunning = false
```

Prevents concurrent reconciliation during rapid sync events.

### Edge Case: Selected Container Deleted

If user's `selectedContainer` is a duplicate being deleted, automatically switch to the canonical container.

## Reconciler Installation

**File:** `AppBootstrapper.swift` - `installReconciler()`

```swift
reconcilerHarness = AppBootstrapper.installReconciler(
    container: container,
    vm: takeNoteVM,
    runOnStartup: true,
    listenForLocalSaves: true,
    searchIndexService: search
)
```

### Notification Observers

**`.NSPersistentStoreRemoteChange`** - CloudKit sync events:
- Run system folder reconciliation
- Trigger search reindex (rate-limited to 10+ minutes between full reindexes)

**`.NSManagedObjectContextDidSave`** (optional) - Local save events:
- Used for testing
- Enabled via `listenForLocalSaves: true`

## Snapshot System

**File:** `SnapshotController.swift`

Widgets can't directly access SwiftData, so snapshots are written to the app group container.

### Snapshot Timing

- On app launch/foreground
- Every 10 minutes while active
- On background/inactive transition

### Snapshot Contents

```swift
struct ContainerSnapshot: Codable {
    let id: UUID
    let name: String
    let symbol: String
    let notes: [NoteSnapshot]  // Max 5 most recent
}

struct NoteSnapshot: Codable {
    let id: UUID
    let title: String
    let content: String  // First ~200 chars
    let updatedDate: Date
}
```

### Storage Location

App group container: `group.com.adamdrew.takenote/snapshot.json`
