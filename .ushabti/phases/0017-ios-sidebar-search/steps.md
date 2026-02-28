# Steps

## S001: Add noteSearchText to TakeNoteVM

**Intent:** Establish the single source of truth for search text in the central state manager, per L09.

**Work:**
- Open `/Users/adam/Development/TakeNote/TakeNote/TakeNoteVM.swift`
- Add `var noteSearchText: String = ""` as a stored property in the UI State section, after `showMultiNoteView`

**Done when:** `TakeNoteVM` has a `noteSearchText: String` property initialized to `""`.

---

## S002: Update NoteList to use TakeNoteVM.noteSearchText (state and binding)

**Intent:** Remove the local `@State var noteSearchText` from `NoteList` and update the `.searchable()` modifier binding to point to the shared state.

**Work:**
- Open `/Users/adam/Development/TakeNote/TakeNote/Views/NoteList/NoteList.swift`
- Remove `@State var noteSearchText: String = ""` (line 64)
- Locate `.searchable(text: $noteSearchText)` (line 267) on the `List`
- On macOS: keep `.searchable()` on the `List` but change the binding to `$takeNoteVM.noteSearchText`. This requires `@Bindable var takeNoteVM = takeNoteVM` — verify this is already present in `body` and use that bindable reference.
- On iOS: wrap the `.searchable()` modifier in `#if os(macOS)` / `#endif` so it only applies on macOS. On iOS the `.searchable()` will be on the `NavigationSplitView` (added in S003).
- Update all references to `noteSearchText` inside `filteredNotes` to read `takeNoteVM.noteSearchText` instead.

**Done when:** `NoteList` has no `@State var noteSearchText`. All references to search text read `takeNoteVM.noteSearchText`. The `.searchable()` on the `List` is macOS-only.

---

## S003: Move .searchable() to NavigationSplitView on iOS and remove broken sidebar DefaultToolbarItem

**Intent:** Wire search to the NavigationSplitView on iOS so the system renders the search bar at the bottom of the sidebar column (Apple Notes pattern), and remove the broken `DefaultToolbarItem(kind: .search)` from the sidebar toolbar that Phase 0016 added.

**Work:**
- Open `/Users/adam/Development/TakeNote/TakeNote/Views/MainWindow/MainWindow.swift`
- Locate the `#if os(iOS)` block inside the sidebar column toolbar (lines ~178-194). Remove the `DefaultToolbarItem(kind: .search, placement: .bottomBar)` line from within this block. Keep the Magic Chat button in that block.
- In `body`, after the `NavigationSplitView { ... } content: { ... } detail: { ... }` closing brace, inside an `#if os(iOS)` block, add `.searchable(text: $takeNoteVM.noteSearchText)` as a modifier on the `NavigationSplitView`. The `@Bindable var takeNoteVM = takeNoteVM` is already declared at the top of `body` — use that binding.
- Verify the content column `DefaultToolbarItem(kind: .search, placement: .bottomBar)` (line ~202) remains present. After moving `.searchable()` to the `NavigationSplitView` on iOS, assess whether this `DefaultToolbarItem` in the content column still wires correctly or whether it should be removed. If removing it does not break the NoteList search functionality on iOS (since the search bar is now sidebar-level), remove it to avoid a duplicate search button in the content column toolbar on iOS. If keeping it is safe and non-intrusive, keep it. Document the decision in step notes.

**Done when:** The sidebar toolbar no longer contains `DefaultToolbarItem(kind: .search)`. The `NavigationSplitView` has `.searchable(text: $takeNoteVM.noteSearchText)` inside an `#if os(iOS)` block. macOS has no `.searchable()` modifier on the `NavigationSplitView`.

---

## S004: Update filteredNotes for global search behavior

**Intent:** When search text is active, results should span all notes (excluding trash and buffer), regardless of which folder is selected. The existing All Notes branch already does this — promote it to be the primary non-empty-search path.

**Work:**
- Open `/Users/adam/Development/TakeNote/TakeNote/Views/NoteList/NoteList.swift`
- Refactor `filteredNotes` so that when `takeNoteVM.noteSearchText` is non-empty, the candidate pool is always all non-trash/non-buffer notes (`notes.filter { $0.folder?.isTrash != true && $0.folder?.isBuffer != true }`) regardless of `selectedContainer`.
- When `takeNoteVM.noteSearchText` is empty, the existing folder-scoped behavior is preserved (return `selectedContainer?.notes ?? []` for non-All-Notes containers; return the all-notes pool for All Notes).
- The refactored structure should be:
  1. Build `allNotesSource` = notes excluding trash and buffer.
  2. If `noteSearchText` is non-empty: FTS search against `allNotesSource` and return ranked results (this is the global search path, same logic as the existing All Notes + search branch).
  3. If `noteSearchText` is empty and `selectedContainer?.isAllNotes == true`: return `allNotesSource`.
  4. If `noteSearchText` is empty and any other container: return `selectedContainer?.notes ?? []`.
- Ensure the FTS ranking sort logic (`indexMap`) is preserved from the existing implementation.

**Done when:** When search text is non-empty, `filteredNotes` returns matching notes from all non-trash/non-buffer notes. When search text is empty, `filteredNotes` returns notes scoped to the selected container (or all notes if All Notes is selected), unchanged from current behavior.

---

## S005: Update views.md documentation

**Intent:** Reconcile the views documentation with the changes made in this Phase (L17, L19).

**Work:**
- Open `/Users/adam/Development/TakeNote/.ushabti/docs/views.md`
- Update the **NoteList** section to reflect:
  - `noteSearchText` is no longer a `@State` property on `NoteList`; search text is now read from `TakeNoteVM.noteSearchText`
  - `.searchable()` is macOS-only on the `List`; on iOS it is on the `NavigationSplitView`
  - When search text is non-empty, `filteredNotes` uses a global candidate pool (all non-trash/non-buffer notes) regardless of selected container
- Update the **MainWindow** section to reflect:
  - On iOS, `.searchable(text: $takeNoteVM.noteSearchText)` is attached to the `NavigationSplitView`
  - The broken `DefaultToolbarItem(kind: .search)` in the sidebar column toolbar has been removed
- Update the **Multi-Platform Adaptations** section if needed to note the search bar placement difference between iOS and macOS

**Done when:** `views.md` accurately describes the new search placement, the global search behavior, and the removal of the sidebar `DefaultToolbarItem`.

---

## S006: Update ai-features.md documentation

**Intent:** Correct the Phase 0016 section of `ai-features.md` that documents the broken search button, and record the correct Phase 0017 fix (L17, L19).

**Work:**
- Open `/Users/adam/Development/TakeNote/.ushabti/docs/ai-features.md`
- Locate the **iOS Sidebar Toolbar Additions (Phase 0016)** section
- Update the **Search Button** subsection to document that:
  - The `DefaultToolbarItem(kind: .search, placement: .bottomBar)` added in Phase 0016 to the sidebar toolbar did not work (no `.searchable()` in that column to wire to)
  - Phase 0017 removed this item and instead attaches `.searchable(text: $takeNoteVM.noteSearchText)` to the `NavigationSplitView` on iOS, following the Apple Notes pattern
  - `noteSearchText` now lives in `TakeNoteVM` as the single source of truth
- If any content in this section or related sections is stale, correct it.

**Done when:** `ai-features.md` accurately records the Phase 0016 sidebar toolbar search button as non-functional, and documents the Phase 0017 fix.
