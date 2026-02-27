# Phase 0012: Image Insertion — Picker, Drag and Drop, and Orphan Culling

## Intent

Deliver the full user-facing image insertion experience for notes: a Photos picker toolbar button, drag-and-drop onto the editor body, and automatic orphan culling so that `NoteImage` records without any referencing note are removed lazily. After this phase, users can insert images from their photo library or by dragging images into the editor, and the system will clean up orphaned image data on note deselection and trash emptying.

## Scope

**In scope:**
- Photos picker toolbar button in `NoteEditor` using `PhotosPicker` from `PhotosUI` (no entitlements required). Disabled in preview mode.
- Image downsizing at import: scale down so the longest dimension is at most 2048px before storing.
- `insertImage(data: Data)` function on `NoteEditor` that: downsizes the image, creates a `NoteImage` record, inserts it into the model context, constructs `![image](takenote://image/<UUID>)` markdown, calls `insertAtCaret(_:)`.
- Drag-and-drop onto the editor body via `.dropDestination(for: Data.self)`, guarded on `!showPreview`. Validates that dropped data decodes as an image before calling `insertImage(data:)`.
- `NoteImageManager` class in `TakeNote/Library/NoteImageManager.swift` (analogous to `NoteLinkManager`) with a `cullOrphanedImages(modelContext:)` method: fetches all `NoteImage` records, fetches all non-trashed and non-buffered notes, uses regex to extract all `takenote://image/<UUID>` references from note content, deletes any `NoteImage` whose `imageUUID` is not referenced.
- Wire `NoteImageManager.cullOrphanedImages` into `NoteList.onChange(of: takeNoteVM.selectedNotes)` alongside the existing `generateSummary`/`reindex`/`generateLinksFor` calls (runs once after processing old selected notes).
- Wire `NoteImageManager.cullOrphanedImages` into `TakeNoteVM.emptyTrash` after the delete loop and save.
- Update `data-models.md` and `supporting-systems.md` to document `NoteImageManager` and the image insertion flow.
- Update `views.md` to document the new toolbar button and drop destination in `NoteEditor`.

**Out of scope:**
- Any changes to the `NoteImage` model, `NoteImageStore`, or `TakeNoteImageProvider` — those are Phase 0011.
- Widget or share extension changes.
- Eager/synchronous culling on every keystroke. Culling is lazy and eventually consistent.

## Constraints

- **L01:** `PhotosPicker` is available on macOS 13+ and iOS 16+, both below our minimums of macOS 26 / iOS 26. No `#available` guards needed.
- **L02:** No new `@Model` types. `NoteImage` was introduced in Phase 0011.
- **L03:** No schema changes in this phase. No version bump required.
- **L09:** `NoteImageManager` follows the inline instantiation pattern of `NoteLinkManager` — instantiated where needed, not injected as a long-lived environment object.
- **L10:** Orphan culling deletes `NoteImage` records only, not `Note` records. The `modelContext.delete(note)` restriction in L10 applies only to `Note`. Deleting `NoteImage` directly is permitted.
- **L16/L17/L18/L19:** `data-models.md`, `supporting-systems.md`, and `views.md` must be updated.
- **Style:** The drag-and-drop destination uses `.dropDestination(for: Data.self)` guarded on `!showPreview`. The toolbar button follows the existing `ToolbarItem(placement: toolbarPosition)` pattern. `NoteImageManager` is `@MainActor @Observable` matching `NoteLinkManager`. Platform image construction uses `UIImage`/`NSImage` behind `#if os(macOS)` guards.

## Acceptance criteria

1. A photo picker toolbar button appears in `NoteEditor` in edit mode (not preview mode), opens `PhotosPicker`, and on selection inserts `![image](takenote://image/<UUID>)` markdown at the caret with a new `NoteImage` record saved.
2. Dropping image data onto the editor body (when `!showPreview`) inserts the image markdown at the caret with a new `NoteImage` record saved.
3. Images are downsized to a maximum longest dimension of 2048px before being stored in `NoteImage.imageData`.
4. `TakeNote/Library/NoteImageManager.swift` exists with `cullOrphanedImages(modelContext:)` that deletes unreferenced `NoteImage` records.
5. On note deselection in `NoteList`, orphan culling runs after the existing per-note processing loop.
6. After `emptyTrash` completes (notes deleted and saved), orphan culling runs.
7. App builds and runs on macOS and iOS simulators without errors.
8. `data-models.md`, `supporting-systems.md`, and `views.md` are updated to reflect the new insertion flow and `NoteImageManager`.

## Risks / notes

- Image downsizing must handle both JPEG and PNG inputs. Store JPEG for photos (smaller) and PNG for lossless sources; the `mimeType` field on `NoteImage` tracks this.
- `PhotosPicker` on macOS presents as a sheet; on iOS it presents as a sheet or popover. Both are handled by SwiftUI automatically.
- Drag and drop on visionOS uses the same `.dropDestination(for: Data.self)` API — no extra platform handling required.
- Culling is lazy and eventually consistent. If CloudKit syncs a new image reference before the local `NoteImage` record arrives, the image URL will render as `EmptyView` in the provider (graceful degradation). The record will not be culled because the reference exists in the note content.
- `NoteImageManager.cullOrphanedImages` fetches all notes to scan content. On a large note library this is a linear scan; acceptable given it only runs on deselection and trash emptying, not per-keystroke.
