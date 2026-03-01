# Steps

## S001: Add `isSearchNavigating` flag to `TakeNoteVM`

**Intent:** Provide a coordination signal that `MainWindow` can set before programmatically switching containers, so `NoteList` knows to suppress the clear-on-switch behavior for that one event.

**Work:**
- In `TakeNote/TakeNoteVM.swift`, add `var isSearchNavigating: Bool = false` to the UI State property block (near line 51, alongside `noteSearchText`).
- Add a brief inline comment explaining its purpose: coordination between search submit and container change handler.

**Done when:** `TakeNoteVM` compiles with the new `isSearchNavigating: Bool` property visible to all views that access the VM.

---

## S002: Add `.onSubmit(of: .search)` to `MainWindow.swift`

**Intent:** When the user presses Enter/Return in the search field with non-empty text, navigate to All Notes and set the coordination flag so the container-change handler in `NoteList` does not clear the search text.

**Work:**
- In `TakeNote/Views/MainWindow/MainWindow.swift`, immediately after the `.searchable(text: $takeNoteVM.noteSearchText)` modifier (line 221), add:

```swift
.onSubmit(of: .search) {
    guard !takeNoteVM.noteSearchText.isEmpty else { return }
    takeNoteVM.isSearchNavigating = true
    takeNoteVM.selectedContainer = takeNoteVM.allNotesFolder
}
```

- No platform guard is needed: `.onSubmit(of: .search)` is available on both macOS and iOS at the minimum deployment targets.

**Done when:** Pressing Enter/Return in a non-empty search field causes the sidebar to highlight All Notes. The search text remains visible in the search bar.

---

## S003: Modify `.onChange(of: takeNoteVM.selectedContainer)` in `NoteList.swift`

**Intent:** Clear `noteSearchText` when the user manually switches folders, but not when the switch was triggered programmatically by the search submit handler.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, replace the existing handler at line 341:

  ```swift
  .onChange(of: takeNoteVM.selectedContainer) { _, _ in rebuildNoteCache() }
  ```

  with:

  ```swift
  .onChange(of: takeNoteVM.selectedContainer) { _, _ in
      if takeNoteVM.isSearchNavigating {
          takeNoteVM.isSearchNavigating = false
      } else {
          takeNoteVM.noteSearchText = ""
      }
      rebuildNoteCache()
  }
  ```

- The flag is checked first. If it is `true`, reset it to `false` and skip clearing. If it is `false`, clear `noteSearchText`. In both cases, `rebuildNoteCache()` is called after, so the note list reflects the current state.

**Done when:** Manually switching folders clears the search text. Pressing Enter/Return in a non-empty search field navigates to All Notes without clearing the search text.

---

## S004: Update documentation

**Intent:** Keep `.ushabti/docs/` accurate per laws L17 and L19.

**Work:**
- In `.ushabti/docs/view-model.md`, under the "UI State" properties table, add a row for `isSearchNavigating`:

  | `isSearchNavigating` | `Bool` | Coordination flag set by the search submit handler before programmatically switching to All Notes. Suppresses the search-text-clear in `NoteList.onChange(of: selectedContainer)` for that one event cycle. Reset to `false` by `NoteList` after reading. |

- In `.ushabti/docs/views.md`, in the `NoteList` section, update the bullet that describes `.onChange(of: takeNoteVM.selectedContainer)` to reflect that it now also clears `noteSearchText` on a user-initiated container switch (conditioned on `isSearchNavigating`). Also update the `MainWindow` section to note the `.onSubmit(of: .search)` modifier and its behavior.

**Done when:** Both docs files accurately describe the new flag and both new behaviors (auto-navigate on submit, clear on manual switch).
