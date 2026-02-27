# Review: Phase 0012 — Image Insertion — Picker, Drag and Drop, and Orphan Culling

## Summary

All ten steps verified. All eight acceptance criteria met. All applicable laws satisfied. Documentation fully reconciled across all affected files. Build confirmed clean. Phase is complete.

## Verified

**Acceptance criteria (all 8 passed):**

1. **Photo picker toolbar button** — `PhotosPicker(selection: $selectedPhotoItem, matching: .images)` in `NoteEditor.swift`. `.disabled(showPreview)` guard in place. `onChange(of: selectedPhotoItem)` loads data via `loadTransferable(type: Data.self)` in a `Task`, calls `insertImage(data:)` on `MainActor`, resets item to `nil` after. Inserts `![image](takenote://image/<UUID>)` markdown with a new `NoteImage` record saved. PASS.

2. **Drag and drop** — `.dropDestination(for: Data.self)` on the root `ZStack`. Returns `false` immediately when `showPreview`. Validates each item via `UIImage(data:)` / `NSImage(data:)`. Calls `insertImage(data:)` per valid item. Returns `true` if at least one was inserted. PASS.

3. **Downsizing to 2048px max** — `maxImageDimension: CGFloat = 2048`. `downsize(imageData:)` implements platform-conditional scaling: `UIImage` + `UIGraphicsImageRenderer` on iOS/visionOS; `NSImage` + `NSBitmapImageRep` on macOS. Re-encodes as JPEG at 0.85 compression. Falls back to original data on failure. PASS.

4. **NoteImageManager** — `TakeNote/Library/NoteImageManager.swift` exists. `@MainActor @Observable final class NoteImageManager`. `cullOrphanedImages()` fetches all `NoteImage` records, fetches non-trashed non-buffered notes, builds referenced UUID set via Swift regex literal, deletes unreferenced records, saves with `try?`, logs count at `.info` level. PASS.

5. **Culling on deselection** — `NoteImageManager(modelContext: modelContext).cullOrphanedImages()` called after the per-note loop in `NoteList.onChange(of: takeNoteVM.selectedNotes)`. PASS.

6. **Culling after emptyTrash** — `NoteImageManager(modelContext: modelContext).cullOrphanedImages()` called at end of `TakeNoteVM.emptyTrash(_:)` after delete loop and save. PASS.

7. **Build** — confirmed by user, zero errors. PASS.

8. **Docs** — `supporting-systems.md`, `views.md`, `data-models.md`, `view-model.md`, and `architecture.md` all reconciled with the code changes. PASS.

**Law compliance:**

- L01: macOS 26.0 / iOS 26.0 targets confirmed. No `#available` guards below these minimums. PASS.
- L02: No new `@Model` types. PASS.
- L03: No schema changes in this phase. No version bump required. PASS.
- L08: Widget extension includes `NoteImageManager.swift` in its membership exceptions set solely to satisfy a compiler dependency from `TakeNoteVM.swift`. No widget code calls `NoteImageManager`, accesses `ModelContainer`, or instantiates any `@Model` type. PASS.
- L09: `NoteImageManager` uses inline instantiation matching `NoteLinkManager` pattern. Not a new environment singleton. PASS.
- L10: `modelContext.delete(image)` deletes `NoteImage` records only. L10 applies exclusively to `Note` deletion outside `emptyTrash()`. PASS.
- L17/L18/L19: All affected documentation reconciled. PASS.
- L20: `CURRENT_PROJECT_VERSION` 13→14, `MARKETING_VERSION` 1.1.9→1.1.10. All four occurrences of each updated in `project.pbxproj`. PASS.

**Style compliance:**

- `NoteImageManager` uses `Logger(subsystem: "com.adamdrew.takenote", category: "NoteImageManager")`. No `print()` in new code. PASS.
- `@MainActor @Observable final class NoteImageManager` matches `NoteLinkManager` pattern. PASS.
- PhotosPicker toolbar item follows `ToolbarItem(placement: toolbarPosition)` pattern. PASS.
- `insertImage(data:)` and `downsize(imageData:)` are `private` / `private static`. PASS.

**Follow-up steps (S008/S009/S010) verified:**

- S008: `views.md` line 89 now reads "...`NoteLinkManager.generateLinksFor()`, and `NoteImageManager.cullOrphanedImages()`." Accurate. PASS.
- S009: `view-model.md` line 115 now reads "permanently deletes all notes in Trash, then runs `NoteImageManager.cullOrphanedImages()` to remove any images that were only referenced by the deleted notes." Accurate. PASS.
- S010: `views.md` line 150 now reads "Returns `(data, "image/jpeg")` on success" — matches actual `(Data, String)` return type. Accurate. PASS.

## Issues

None.

## Required follow-ups

None.

## Decision

**GREEN.**

Phase 0012 is complete. All acceptance criteria met, all laws satisfied, all documentation reconciled. Weighed and found true. Hand off to Ushabti Scribe for the next Phase.
