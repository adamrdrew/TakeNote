# Steps

## S001: Replace `foregroundColor()` with `foregroundStyle()`

**Intent:** Eliminate deprecated `foregroundColor` API usage across all affected view files.

**Work:**
- In `NoteListEntry.swift`: replace `.foregroundColor(iconColor)` (lines 196, 248), `.foregroundColor(noteLabel.getColor())` (line 261), `.foregroundColor(.white)` (line 331), `.foregroundColor(.gray)` (lines 336, 339, 342) with `.foregroundStyle(...)` equivalents.
- In `NoteListHeader.swift`: replace `.foregroundColor(takeNoteVM.selectedContainer?.getColor() ?? .takeNotePink)` (line 93) with `.foregroundStyle(...)`.
- In `FolderListEntry.swift`: replace the two `.foregroundColor(...)` calls (lines 110-116) — Step 7 will handle the colorScheme-branching one; this step replaces the `folder.isSystemFolder ? .takeNotePink : folder.getColor()` call with `.foregroundStyle(...)`.
- In `TagListEntry.swift`: replace `.foregroundColor(tag.getColor())` (line 83) with `.foregroundStyle(tag.getColor())`.
- In `MessageBubble.swift`: replace `.foregroundColor(isHuman ? .white : .primary)` (line 144) with `.foregroundStyle(isHuman ? .white : .primary)`.
- In `ContextBubble.swift`: replace `.foregroundColor(.primary)` (line 35) with `.foregroundStyle(.primary)`.

**Done when:** `grep -rn "\.foregroundColor(" TakeNote/Views/` returns no results in any of the six files listed above.

---

## S002: Add `private` to all `@State` and `@FocusState` declarations

**Intent:** Satisfy the SwiftUI requirement that `@State` is `private` to signal ownership to the diffing engine and prevent external mutation.

**Work:**
- `MainWindow.swift`: add `private` to `notesInBufferMessagePresented`, `showDeleteEverythingAlert`, `showChatPopover`, `showSidebarChatPopover`, `showSortPopover` (lines 31-38).
- `NoteList.swift`: add `private` to `showFileImportError`, `fileImportErrorMessage`, `noteDeleteRegistry`, `noteRenameRegistry`, `noteStarToggleRegistry`, `noteCopyMarkdownLinkRegistry`, `noteOpenEditorWindowRegistry` (lines 62-70).
- `NoteListEntry.swift` (`MovePopoverContent`): add `private` to `selectedContainer` (line 20).
- `NoteListHeader.swift`: add `private` to `inEditMode`, `newName`, `nameInputFocused` (lines 15-17).
- `Sidebar.swift`: add `private` to `folderSectionExpanded`, `tagSectionExpanded`, `showImportError`, `importErrorMessage`, `containerDeleteRegistry`, `containerRenameRegistry`, `tagSetColorRegistry` (lines 117-124).
- `FolderListEntry.swift`: add `private` to `inDeleteMode` (line 29).
- `TagListEntry.swift`: add `private` to `inDeleteMode`, `inRenameMode`, `newTagName`, `showEditDetailsPopover` (lines 16, 22-24).
- `NoteContainerDetailsEditor.swift`: add `private` to `newTagColor`, `noteContainer`, `newSymbol`, `newName` (lines 14, 16-18). Line 15 (`@Binding var showColorPopover`) is a `@Binding` and must NOT receive `private`.
- `NoteEditorWindow.swift`: add `private` to `windowTitle` (line 14).
- `NoteEditor.swift`: add `private` to `isInputActive` `@FocusState` (line 103).

**Done when:** `grep -n "@State var\|@FocusState var" TakeNote/Views/**/*.swift` returns no results without `private` (excluding `@Binding var` declarations).

---

## S003: Cache `NoteList` filter and sort results

**Intent:** Prevent `filteredNotes` and `sortedNotes` from re-running their full pipeline on every `body` evaluation. These currently perform a full array filter, FTS index lookup, `Dictionary` construction, and sort on every render.

**Work:**
- Remove the `var filteredNotes: [Note]` and `var sortedNotes: [Note]` computed properties from `NoteList`.
- Add `@State private var cachedFilteredNotes: [Note] = []` and `@State private var cachedSortedNotes: [Note] = []` state properties.
- Add `@State private var cachedStarredNotes: [Note] = []` and `@State private var cachedUnstarredNotes: [Note] = []` to pre-split the list for the two ForEach sections.
- Add a private method `rebuildNoteCache()` that replicates the logic previously in `filteredNotes` and `sortedNotes`, then populates all four cached arrays. This method must use `search.searchNoteIDs` for search results, respect `takeNoteVM.noteSearchText`, `takeNoteVM.selectedContainer`, `takeNoteVM.sortBy`, and `takeNoteVM.sortOrder`.
- Wire `rebuildNoteCache()` via `.onChange(of:)` for all five inputs: `notes`, `takeNoteVM.noteSearchText`, `takeNoteVM.selectedContainer`, `takeNoteVM.sortBy`, `takeNoteVM.sortOrder`.
- Also call `rebuildNoteCache()` in `.onAppear` to populate the cache on first load.
- Update all `body` references from `filteredNotes` / `sortedNotes` to `cachedFilteredNotes` / `cachedSortedNotes`.
- Update the `folderHasStarredNotes()` function and all ForEach sections that previously did `if note.starred` / `if !note.starred` inline to use the pre-split `cachedStarredNotes` / `cachedUnstarredNotes` arrays directly.
- The `showUnstarredNoteList` computed property may remain as-is since it checks `cachedSortedNotes` (which is already computed).

**Done when:** `NoteList.swift` contains no computed properties named `filteredNotes` or `sortedNotes`. All `body` ForEach sections reference the cached `@State` arrays. Note list renders correctly under search and non-search conditions.

---

## S004: Cache `NoteListHeader` note count

**Intent:** The `allNotes.filter { ... }.count` expression inside the `noteCount` computed property currently runs on every `body` evaluation. Replace it with a cached count updated by `onChange`.

**Work:**
- In `NoteListHeader.swift`, add `@State private var cachedNoteCount: Int = 0`.
- Add a private method `rebuildNoteCount()` that computes the count using the same logic as the current inline expression (filter `allNotes` excluding trash/buffer for the `isAllNotes` case, or use `container.notes.count` otherwise).
- Wire `rebuildNoteCount()` via `.onChange(of: allNotes)` and `.onChange(of: takeNoteVM.selectedContainer)`.
- Call `rebuildNoteCount()` in `.onAppear`.
- Update `noteCount` to return `cachedNoteCount` (or convert the computed property to use the state directly in the body).

**Done when:** `NoteListHeader.swift` contains no `allNotes.filter { ... }.count` expression in a computed property body. Note count displays correctly when switching containers.

---

## S005: Cache Sidebar system folder sort

**Intent:** The `systemFolders.sorted(by:)` call inside the `ForEach` in `Sidebar.body` re-sorts on every render. Move this to a cached computed property or `@State` so the sort only runs when `systemFolders` changes.

**Work:**
- In `Sidebar.swift`, add a private computed property `sortedSystemFolders: [NoteContainer]` that returns `systemFolders.sorted(by: { systemFolderSortOrder($0) < systemFolderSortOrder($1) })`.
- Replace the inline `.sorted(by:)` call in the `ForEach` on line 135 with `sortedSystemFolders`.
- (Note: because `systemFolders` is a `@Query` result and SwiftUI will re-evaluate the computed property only when the query result changes, a simple computed property is sufficient here — a `@State` cache with `onChange` is not required since `@Query` results already avoid spurious body re-evaluations. However, if Builder prefers `@State` + `onChange`, that is also acceptable.)

**Done when:** The `ForEach` in `Sidebar.body` iterates `sortedSystemFolders` (or equivalent cached value), not `systemFolders.sorted(by:)` inline.

---

## S006: Replace `[Note]` with `[UUID: String]` in `MessageBubble` and `ChatWindow`

**Intent:** Passing the full `allNotes: [Note]` array to every `MessageBubble` causes all visible chat bubbles to re-render whenever any note changes anywhere in the app. A pre-computed `[UUID: String]` dictionary of note titles limits re-renders to cases where the dictionary content actually changes.

**Work:**
- In `MessageBubble.swift`: change the `notes: [Note]` property (line 51) to `noteTitles: [UUID: String]`.
- Update all references inside `MessageBubble` that previously resolved a source note title via the `notes` array to instead look up by UUID in `noteTitles`.
- In `ChatWindow.swift`: replace the `allNotes` array passed to each `MessageBubble` with a computed dictionary. Add a private computed property `noteTitleMap: [UUID: String]` that maps `allNotes.map { ($0.uuid, $0.title) }` into a dictionary. Pass `noteTitleMap` to each `MessageBubble(entry:onBotMessageClick:noteTitles:)` call.

**Done when:** `MessageBubble` has no `[Note]` property. `ChatWindow` passes `noteTitles: noteTitleMap` to each `MessageBubble`. Chat source-note titles still resolve and display correctly.

---

## S007: Replace `AnyView` in `TakeNoteImageProvider` with `@ViewBuilder`

**Intent:** `AnyView` erases type information and suppresses SwiftUI's structural diffing. The three branches in `makeImage(url:)` can be expressed with a `@ViewBuilder` function, which preserves type information and allows the framework to diff the view tree correctly.

**Work:**
- In `TakeNoteImageProvider.swift`, change `func makeImage(url: URL?) -> some View` to annotate the function body with `@ViewBuilder` (the return type remains `some View`).
- Remove all `return AnyView(...)` wrapping. Replace with direct view expressions inside the conditional branches.
- Preserve the `#if os(macOS)` / `#else` conditional compilation structure exactly as-is.
- The fallthrough `return AnyView(EmptyView())` cases become `EmptyView()`.

**Done when:** `TakeNoteImageProvider.swift` contains no `AnyView`. Image rendering in Markdown preview mode works correctly on both platforms.

---

## S008: Extract `onChange(of: takeNoteVM.selectedNotes)` body into named method

**Intent:** The ~20-line inline closure in `NoteList.swift`'s `onChange(of: takeNoteVM.selectedNotes)` mixes note selection callbacks, summary generation, search reindexing, link generation, title setting, and image culling. Extracting to a named method improves readability and testability.

**Work:**
- In `NoteList.swift`, add a private method `handleNoteSelectionChange(old: Set<Note>, new: Set<Note>)`.
- Move all logic currently inside the `onChange(of: takeNoteVM.selectedNotes) { oldValue, newValue in ... }` closure body into this method.
- Replace the closure body with a single call: `handleNoteSelectionChange(old: oldValue, new: newValue)`.

**Done when:** The `onChange(of: takeNoteVM.selectedNotes)` closure body is a single method call. The extracted method `handleNoteSelectionChange(old:new:)` exists and contains the original logic unchanged.

---

## S009: Remove unnecessary `colorScheme` branching in `FolderListEntry` and `TagListEntry`

**Intent:** The manual `colorScheme == .light ? Color.primary : Color.white` expressions duplicate what `.foregroundStyle(.primary)` already handles adaptively. Removing this redundancy also allows removing the unused `@Environment(\.colorScheme)` injection from each file.

**Work:**
- In `FolderListEntry.swift` (lines 110-113): replace `.foregroundColor(colorScheme == .light ? Color.primary : Color.white)` with `.foregroundStyle(.primary)`. (This step completes the `foregroundColor` replacement in this file that Step 1 started for the other call in line 116.)
- In `TagListEntry.swift` (lines 87-89): replace `.foregroundColor(colorScheme == .light ? Color.primary : Color.white)` (or equivalent expression) with `.foregroundStyle(.primary)`.
- If `@Environment(\.colorScheme) var colorScheme` is now unreferenced in either file after these changes, remove the declaration.

**Done when:** Neither `FolderListEntry.swift` nor `TagListEntry.swift` contains a `colorScheme ==` conditional expression for foreground color. The `@Environment(\.colorScheme)` injection is removed from each file where it is no longer used.

---

## S010: Remove redundant outer `ZStack` in `MultiNoteViewer`

**Intent:** `MultiNoteViewer.body` wraps a `GeometryReader` containing a single inner `ZStack` inside an outer `ZStack`. The outer `ZStack` adds no layout or visual meaning. Removing it simplifies the view hierarchy.

**Work:**
- In `MultiNoteViewer.swift`, remove the outer `ZStack { ... }` wrapper in `body`. The `GeometryReader { geo in ... }` becomes the direct content of `body`. Keep the `.frame(maxWidth: .infinity, maxHeight: .infinity)` modifier that was on the outer `ZStack` — move it to the `GeometryReader` if needed, or confirm it is already on the inner structure.
- The inner `ZStack` (the one wrapping the `ForEach` of `PaperCard`) is not `MultiNoteViewer`'s direct body ZStack — it is inside `GeometryReader` and must not be removed.

**Done when:** `MultiNoteViewer.body` does not have an outer `ZStack` wrapping the `GeometryReader`. The multi-note "messy pile" visual renders correctly with no layout regression.

---

## S011: Make `Logger` properties `static let`

**Intent:** `let logger = Logger(...)` declared as an instance property on a `View` struct allocates a new `Logger` on every view instantiation. `Logger` is a value type backed by a `os_log_t` handle; `static let` is the idiomatic pattern that shares the handle across all instances.

**Work:**
- In `MainWindow.swift` (line 29): change `let logger = Logger(...)` to `static let logger = Logger(...)`.
- In `NoteEditor.swift` (line 117): change `let logger = Logger(...)` to `static let logger = Logger(...)`.
- Update any call sites that reference `self.logger` or `logger` inside closures that capture `self` — since the property is now `static`, references change to `MainWindow.logger` / `NoteEditor.logger` respectively (or remain unqualified since Swift resolves the static member automatically when unambiguous).

**Done when:** Both `MainWindow.logger` and `NoteEditor.logger` are `static let`. No new compiler warnings or errors are introduced.

---

## S012: Update documentation

**Intent:** The views documentation in `.ushabti/docs/views.md` references `filteredNotes` and `sortedNotes` as computed properties on `NoteList`, and does not mention the `noteTitleMap` pattern in `ChatWindow`. These references must be updated to reflect the implementation.

**Work:**
- In `.ushabti/docs/views.md`, update the `NoteList` section to describe `cachedFilteredNotes` / `cachedSortedNotes` as `@State` arrays populated by `rebuildNoteCache()` triggered via `onChange`, replacing the description of computed properties.
- Update the `ChatWindow` section to note that `MessageBubble` accepts `noteTitles: [UUID: String]` instead of `notes: [Note]`, and that `ChatWindow` pre-computes `noteTitleMap`.
- Update the `NoteListHeader` section to note that note count is cached in `@State` rather than computed inline in the body.

**Done when:** `.ushabti/docs/views.md` accurately reflects all caching changes made in Steps 3, 4, and 6.
