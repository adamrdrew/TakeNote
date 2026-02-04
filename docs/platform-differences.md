# Platform Differences

TakeNote supports macOS, iOS, iPadOS, and has limited visionOS considerations.

## Compilation Flags

```swift
#if os(macOS)
    // macOS-specific code
#endif

#if os(iOS)
    // iOS/iPadOS-specific code
#endif

#if !os(visionOS)
    // Excluded from visionOS
#endif
```

## App Scene Structure

**File:** `TakeNoteApp.swift`

### macOS

Uses `Window` for single-instance main window:

```swift
#if os(macOS)
    Window("TakeNote", id: "main-window") {
        MainAppWindow
    }
#endif
```

### iOS/iPadOS

Uses `WindowGroup` for multi-window support:

```swift
#if os(iOS)
    WindowGroup(id: "main-window") {
        MainAppWindow
    }
#endif
```

## Initial Selection

**File:** `TakeNoteVM.swift` - `folderInit()`

### macOS

Auto-selects Inbox folder on launch:

```swift
#if os(macOS)
    selectedContainer = inboxFolder
#endif
```

### iPhone

Starts with no selection (shows container list):

```swift
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .pad {
        selectedContainer = inboxFolder
    }
    // iPhone: selectedContainer remains nil
#endif
```

### iPad

Behaves like macOS (auto-selects Inbox).

## Navigation

### macOS

- Three-column split view always visible
- Sidebar collapsible
- Multiple windows supported via separate WindowGroup

### iOS

- NavigationStack-based drilling
- Swipe-back navigation
- Full-screen on iPhone

### iPad

- Split view with sidebar
- Swipe gestures for actions
- Multi-window support

## Editor Behavior

### macOS

**File:** `NoteEditor.swift`

- Escape key exits preview mode:

```swift
#if os(macOS)
.onKeyPress(.escape) {
    if isPreviewing {
        isPreviewing = false
        return .handled
    }
    return .ignored
}
#endif
```

- Double-click opens separate editor window
- No on-screen keyboard shortcuts needed

### iOS

- Tap toggles preview mode:

```swift
#if os(iOS)
.onTapGesture {
    if isPreviewing {
        isPreviewing = false
    }
}
#endif
```

- Markdown shortcuts toolbar when keyboard visible:

```swift
.safeAreaInset(edge: .bottom) {
    if inputFocused && !isPreviewing && !hasHardwareKeyboard {
        // Markdown shortcut buttons
    }
}
```

- Hardware keyboard detection:

```swift
var hasHardwareKeyboard: Bool {
    GCKeyboard.coalesced != nil
}
```

## Note List Actions

### macOS

- Context menu for all actions
- Double-click to open in window
- Keyboard shortcuts

### iOS

- Swipe actions:

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) {
        vm.moveNoteToTrash(note, modelContext: modelContext)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}

.swipeActions(edge: .leading) {
    Button {
        vm.noteStarredToggle(note, modelContext: modelContext)
    } label: {
        Label(note.starred ? "Unstar" : "Star",
              systemImage: note.starred ? "star.slash" : "star.fill")
    }
}
```

- Long-press context menu
- Gesture-based move to folder

## Chat Window

### macOS

Opens as separate window:

```swift
WindowGroup("TakeNote - AI Chat", id: "chat-window") {
    ChatWindow()
}
```

### iOS

Presented as sheet or popover depending on context.

## Color System

**File:** `NoteContainer.swift`

Different color space handling:

```swift
var color: Color {
    #if os(macOS)
        return Color(nsColor: NSColor(...))
    #elseif os(visionOS)
        return Color(uiColor: UIColor(...))
    #else
        return Color(uiColor: UIColor(...))
    #endif
}
```

## Glass Effects

**File:** Various views

Glass background effects excluded from visionOS:

```swift
#if !os(visionOS)
    .glassEffect()
#endif
```

## Search Bar

### macOS

Integrated in toolbar.

### iOS

**File:** `NoteList.swift`

Toolbar-based with collapse behavior:

```swift
.searchable(text: $searchText, placement: .toolbar)
.searchPresentationToolbarBehavior(.minimizesOnScroll)
```

## Copy/Paste

### macOS

Uses `NSPasteboard`:

```swift
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)
```

### iOS

Uses `UIPasteboard`:

```swift
UIPasteboard.general.string = text
```

## System Sounds

### macOS

Error feedback via system sounds:

```swift
NSSound.beep()
```

### iOS

Uses haptic feedback instead.

## File Import

Platform-appropriate file pickers via `.fileImporter()` modifier, which handles the differences automatically.

## Widgets

Both platforms support:
- Home screen widgets
- Lock screen widgets
- Control Center controls

Widget code shared in `NewNoteControl/` target with app group for data sharing.
