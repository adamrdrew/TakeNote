# Steps

## S001: Add NoteImageManager with cullOrphanedImages

**Intent:** Provide the orphan-culling service that removes `NoteImage` records no longer referenced by any note's markdown content.

**Work:**
- Create `TakeNote/Library/NoteImageManager.swift`.
- Define `@MainActor @Observable final class NoteImageManager` with a `var modelContext: ModelContext` stored property and an `os.Logger`.
- Add `init(modelContext: ModelContext)`.
- Implement `func cullOrphanedImages()`:
  - Fetch all `NoteImage` records via `FetchDescriptor<NoteImage>()`.
  - Fetch all notes that are not in Trash and not in Buffer: `FetchDescriptor<Note>` with predicate `$0.folder?.isTrash != true && $0.folder?.isBuffer != true`.
  - Build the set of all referenced image UUIDs by scanning each note's `content` with the regex pattern `takenote://image/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})` (case-insensitive, using Swift regex literal `#/(?i)takenote:\/\/image\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/#`).
  - Delete any `NoteImage` whose `imageUUID` is not in the referenced set.
  - Call `try? modelContext.save()`.
  - Log the count of deleted images at `.info` level.

**Done when:** `NoteImageManager.swift` compiles. `cullOrphanedImages()` correctly identifies and deletes orphaned image records.

---

## S002: Wire orphan culling into NoteList note deselection

**Intent:** Ensure orphaned images are cleaned up whenever the user navigates away from a note.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, locate the `onChange(of: takeNoteVM.selectedNotes)` closure.
- After the existing `for note in oldValue` loop (which calls `generateSummary`, `reindex`, `generateLinksFor`, `setTitle`), instantiate `NoteImageManager(modelContext: modelContext)` and call `.cullOrphanedImages()`.
- Follow the same inline instantiation pattern as `NoteLinkManager`.

**Done when:** `NoteList.swift` compiles. Orphan culling runs on note deselection.

---

## S003: Wire orphan culling into emptyTrash

**Intent:** Ensure that emptying the trash also removes any `NoteImage` records that were only referenced by the now-deleted notes.

**Work:**
- In `TakeNote/TakeNoteVM.swift`, in `emptyTrash(_ modelContext: ModelContext)`:
  - After the `try modelContext.save()` call (and inside the do-catch block or after it), instantiate `NoteImageManager(modelContext: modelContext)` and call `.cullOrphanedImages()`.
- Note: `emptyTrash` is `@MainActor` so this is safe.

**Done when:** `TakeNoteVM.swift` compiles. After emptying trash, orphaned `NoteImage` records are deleted.

---

## S004: Add insertImage function to NoteEditor

**Intent:** Provide the core image insertion logic: downsize, create NoteImage, insert markdown at caret.

**Work:**
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`, add a private function `insertImage(data: Data)`:
  - Downsize the image so the longest dimension is at most 2048px:
    - On iOS/visionOS: use `UIImage(data: data)`, compute scale factor, redraw into a `UIGraphicsImageRenderer` at the new size, export as JPEG (`jpegData(compressionQuality: 0.85)`).
    - On macOS: use `NSImage(data: data)`, compute scale factor, draw into `NSBitmapImageRep` at the new size, export as JPEG (`representation(using: .jpeg, properties: [.compressionFactor: 0.85])`).
    - If downsizing fails, fall back to the original data.
    - Set `mimeType` to `"image/jpeg"` if JPEG was produced, `"image/png"` if the original PNG data is used as fallback.
  - Create `NoteImage(imageData: downsizedData, mimeType: mimeType)`.
  - Insert the record: `modelContext.insert(newImage)`.
  - Save: `try? modelContext.save()`.
  - Construct the markdown string: `"![image](takenote://image/\(newImage.imageUUID.uuidString))"`.
  - Call `insertAtCaret(markdownString)`.
  - Log the insertion at `.info` level.

**Done when:** `insertImage(data:)` compiles on both platforms. Calling it creates a `NoteImage` record and inserts the markdown reference.

---

## S005: Add PhotosPicker toolbar button

**Intent:** Give users a toolbar button to insert images from their photo library.

**Work:**
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`:
  - Import `PhotosUI`.
  - Add `@State private var selectedPhotoItem: PhotosPickerItem?` to the view state.
  - In the `.toolbar` block, add a new `ToolbarItem(placement: toolbarPosition)` containing a `PhotosPicker(selection: $selectedPhotoItem, matching: .images)` with a label using `Image(systemName: "photo.badge.plus")`.
  - Disable the picker when `showPreview == true`.
  - Add `.onChange(of: selectedPhotoItem)` that loads data via `selectedPhotoItem?.loadTransferable(type: Data.self)` in a `Task`, then calls `insertImage(data:)` on the main actor.
  - After processing, set `selectedPhotoItem = nil`.

**Done when:** The toolbar button appears in edit mode, is hidden/disabled in preview mode, and successfully inserts image markdown when a photo is selected.

---

## S006: Add drag-and-drop onto the editor body

**Intent:** Allow users to drag images directly onto the note editor to insert them.

**Work:**
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`, add `.dropDestination(for: Data.self)` to the editor's root `ZStack` (or the `GeometryReader` wrapping the `CodeEditor`):
  - Guard: only active when `!showPreview` (use the `isTargeted` closure or check `showPreview` in the `perform` closure and return `false` if in preview mode).
  - In the `perform` closure: for each item in `items`, validate it is image data (`UIImage(data:)` on iOS, `NSImage(data:)` on macOS — if nil, skip). Call `insertImage(data: item)`. Return `true` if at least one image was inserted.

**Done when:** Dropping image data onto the editor in edit mode inserts the image markdown. Dropping in preview mode has no effect (returns `false`).

---

## S007: Update docs

**Intent:** Keep documentation accurate per L17/L18/L19.

**Work:**
- Update `.ushabti/docs/supporting-systems.md`:
  - Add a `NoteImageManager` section documenting `cullOrphanedImages()`, its regex pattern, fetch strategy, and the two trigger points (note deselection, `emptyTrash`).
- Update `.ushabti/docs/views.md`:
  - In the `NoteEditor` section, document the new `PhotosPicker` toolbar button, the `insertImage(data:)` function, and the `.dropDestination(for: Data.self)` modifier.
- Update `.ushabti/docs/data-models.md`:
  - In the `NoteImage` section (added in Phase 0011), note that image markdown references use the pattern `![image](takenote://image/<UUID>)` and that orphan culling is managed by `NoteImageManager`.

**Done when:** All three doc files are updated and accurately reflect the code introduced in this phase.

---

## S008: Fix views.md NoteList deselection doc omission

**Intent:** Bring `views.md` into full accuracy for the NoteList section, which currently omits the NoteImageManager culling step added in this phase.

**Work:**
- In `.ushabti/docs/views.md`, locate the NoteList section bullet: "On note deselection (oldValue): triggers `generateSummary()`, `SearchIndexService.reindex()`, and `NoteLinkManager.generateLinksFor()`."
- Append `, and `NoteImageManager.cullOrphanedImages()` (after the existing per-note loop)` so the description accurately reflects the code.

**Done when:** The NoteList deselection bullet in `views.md` includes the NoteImageManager culling call.

---

## S009: Fix view-model.md emptyTrash doc omission

**Intent:** Bring `view-model.md` into full accuracy for the `emptyTrash` method, which now calls `NoteImageManager.cullOrphanedImages()` after deleting notes.

**Work:**
- In `.ushabti/docs/view-model.md`, locate the `emptyTrash` method description: "`emptyTrash(_ modelContext: ModelContext)` — permanently deletes all notes in Trash."
- Append so it reads: "`emptyTrash(_ modelContext: ModelContext)` — permanently deletes all notes in Trash, then calls `NoteImageManager.cullOrphanedImages()` to remove any `NoteImage` records that were only referenced by the deleted notes."

**Done when:** The `emptyTrash` description in `view-model.md` reflects the orphan culling step.

---

## S010: Fix views.md downsize return-tuple order inaccuracy

**Intent:** Correct the inaccurate tuple-return description in the `downsize(imageData:)` doc, which currently shows `("image/jpeg", data)` but the actual return type is `(Data, String)`.

**Work:**
- In `.ushabti/docs/views.md`, locate the `downsize(imageData:)` paragraph in the NoteEditor section.
- Change "Returns `("image/jpeg", data)` on success" to "Returns `(data, "image/jpeg")` on success" to match the actual `(Data, String)` return order.

**Done when:** The downsize return-tuple description in `views.md` correctly reflects `(Data, String)` order — data first, mime type second.
