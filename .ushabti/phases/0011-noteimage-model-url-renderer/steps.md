# Steps

## S001: Add NoteImage model

**Intent:** Define the SwiftData model that stores binary image data with a stable UUID identifier.

**Work:**
- Create `TakeNote/Models/NoteImage.swift`.
- Open with `// Hey! // Hey you!` and "And don't forget to promote to prod!!!" reminder comments (matching style of other model files).
- Declare `@Model final class NoteImage` with fields: `var imageUUID: UUID`, `var imageData: Data`, `var mimeType: String`, `var createdDate: Date`.
- Make `imageUUID` `private(set)` via a stored property with a `private(set)` setter.
- Provide all fields with default values in the property declaration so SwiftData can hydrate without the designated initializer.
- Provide a designated initializer `init(imageData: Data, mimeType: String)` that generates a fresh `UUID` for `imageUUID` and sets `createdDate = Date()`.
- No `@Relationship` declarations — `NoteImage` is intentionally freestanding.

**Done when:** `NoteImage.swift` compiles cleanly with `@Model`, `private(set) imageUUID`, and the schema reminder comment.

---

## S002: Bump schema version and add NoteImage to ModelContainer

**Intent:** Honor L03 by bumping the CloudKit bootstrap version and registering `NoteImage` in all relevant container and bootstrap call sites.

**Work:**
- In `TakeNote/TakeNoteApp.swift`, change `ckBootstrapVersionCurrent` from `9` to `10`.
- Add `NoteImage.self` to the array passed to `AppBootstrapper.bootstrapDevSchemaIfNeeded(modelTypes:...)`.
- Add `NoteImage.self` to the `ModelContainer(for: Note.self, NoteContainer.self, NoteLink.self, ...)` call — it becomes the fourth argument.

**Done when:** `ckBootstrapVersionCurrent == 10` and `NoteImage.self` appears in both the bootstrap call and the `ModelContainer(for:)` call in `TakeNoteApp.swift`.

---

## S003: Add NoteImageStore service

**Intent:** Provide a single, reusable data-access function for loading image data by UUID from SwiftData.

**Work:**
- Create `TakeNote/Library/NoteImageStore.swift`.
- Define `enum NoteImageStore` (a caseless enum used as a namespace, consistent with the free-function pattern used in `FileImport.swift` for namespace-like grouping, or use a struct with only static members — either is acceptable; choose the simpler form).
- Implement `static func loadImage(uuid: UUID, modelContext: ModelContext) -> Data?`:
  - `FetchDescriptor<NoteImage>` with predicate `$0.imageUUID == uuid`.
  - Return `results.first?.imageData` or `nil`.
- Add `os.Logger` for the subsystem and category.

**Done when:** `NoteImageStore.swift` compiles. `loadImage(uuid:modelContext:)` returns `Data?` by fetching `NoteImage` records.

---

## S004: Add TakeNoteImageProvider

**Intent:** Implement the MarkdownUI `ImageProvider` that resolves `takenote://image/<UUID>` URLs to image data and renders them inline in preview mode.

**Work:**
- Create `TakeNote/Library/TakeNoteImageProvider.swift`.
- Import `MarkdownUI`, `SwiftData`, `SwiftUI`.
- Define `struct TakeNoteImageProvider: ImageProvider` with a stored `let modelContext: ModelContext`.
- Implement `func makeImage(url: URL?) -> some View`:
  - Guard `url?.scheme == "takenote"` and `url?.host == "image"`.
  - Extract UUID string from `url?.pathComponents.last` and parse it with `UUID(uuidString:)`.
  - Call `NoteImageStore.loadImage(uuid: uuid, modelContext: modelContext)`.
  - If data is present, create a platform-appropriate `Image` from the data (use `UIImage` on iOS/visionOS, `NSImage` on macOS via `#if os(macOS)` guard).
  - Return a resizable, scaledToFit image constrained to a reasonable max width (e.g., `.frame(maxWidth: 400)`).
  - Return `EmptyView()` for any failure path.

**Done when:** `TakeNoteImageProvider.swift` compiles without error on macOS and iOS targets. The struct conforms to `ImageProvider`.

---

## S005: Wire TakeNoteImageProvider into NoteEditor preview

**Intent:** Apply the custom image provider to the MarkdownUI `Markdown` view so that `takenote://image/<UUID>` references render as images in preview mode.

**Work:**
- In `TakeNote/Views/NoteEditor/NoteEditor.swift`, locate `Markdown(note.content)` in the `showPreview` branch.
- Add `.markdownImageProvider(TakeNoteImageProvider(modelContext: modelContext))` as a modifier on the `Markdown` view.
- `modelContext` is already available as `@Environment(\.modelContext) var modelContext` in `NoteEditor`.

**Done when:** `NoteEditor.swift` compiles. The `Markdown` view has the custom provider modifier applied.

---

## S006: Update MainWindow — onOpenURL routing and deleteEverything

**Intent:** Prevent image URLs from being misrouted as note deep links, and ensure the DEBUG delete-all function purges `NoteImage` records.

**Work:**
- In `TakeNote/Views/MainWindow/MainWindow.swift`:
  - Add `@Query() var noteImages: [NoteImage]` to the view's query properties.
  - In `deleteEverything()`, add a loop that deletes each item in `noteImages` via `modelContext.delete(image)`.
  - In `onOpenURL`, before calling `takeNoteVM.loadNoteFromURL`, check `url.host == "image"`: if so, log at `.info` level ("Received image URL in onOpenURL — ignoring as in-process only") and return.

**Done when:** `MainWindow.swift` compiles. `deleteEverything()` deletes `NoteImage` records. `onOpenURL` does not call `loadNoteFromURL` for image URLs.

---

## S007: Update docs

**Intent:** Keep `data-models.md` and `architecture.md` accurate so Overseer can reconcile docs as required by L18/L19.

**Work:**
- Update `.ushabti/docs/data-models.md`:
  - Add a `NoteImage` section documenting fields (`imageUUID`, `imageData`, `mimeType`, `createdDate`), the private setter on `imageUUID`, the no-relationships design decision, and the designated initializer.
  - Update the overview sentence to mention four model types.
- Update `.ushabti/docs/architecture.md`:
  - In the component map, update the Models entry to include `NoteImage`.
  - In the URL Scheme section, note that `onOpenURL` now routes by host: `"note"` → `loadNoteFromURL`, `"image"` → ignored (in-process only).
  - Update the CloudKit Schema Management note to reference version 10.

**Done when:** Both doc files are updated and accurately reflect the code changes made in this phase.
