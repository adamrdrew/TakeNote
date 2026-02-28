# Phase 0011: NoteImage Model, URL Handler, and Preview Rendering

## Intent

Introduce the `NoteImage` SwiftData model, the in-process URL loader (`NoteImageStore`), and the custom MarkdownUI `ImageProvider` that renders `takenote://image/<UUID>` URLs in preview mode. This phase lays the complete data and rendering foundation for images in notes, stopping short of any image insertion UI. Nothing is user-visible at the end of this phase except that the existing preview renderer will correctly resolve and display images whose markdown is already present.

## Scope

**In scope:**
- `NoteImage` `@Model` class in `TakeNote/Models/NoteImage.swift` with fields `imageUUID: UUID` (private setter), `imageData: Data`, `mimeType: String`, `createdDate: Date`. No SwiftData relationships to `Note`.
- `NoteImageStore` service struct in `TakeNote/Library/NoteImageStore.swift` with a single static method `loadImage(uuid:modelContext:) -> Data?` that fetches a `NoteImage` by `imageUUID` from SwiftData.
- `TakeNoteImageProvider` struct in `TakeNote/Library/TakeNoteImageProvider.swift` conforming to MarkdownUI's `ImageProvider`. Checks `url?.scheme == "takenote"` and `url?.host == "image"`, extracts UUID from the path, calls `NoteImageStore.loadImage`, renders a SwiftUI `Image` from the data. Falls back to `EmptyView` when UUID is absent or the image record is not found.
- Wire `.markdownImageProvider(TakeNoteImageProvider(modelContext:))` onto the `Markdown(note.content)` call in `NoteEditor`'s preview path.
- Update `onOpenURL` in `MainWindow` to guard against the `"image"` host (log and return without error rather than calling `loadNoteFromURL`, which would fail on an image URL).
- Bump `ckBootstrapVersionCurrent` from 9 to 10 in `TakeNoteApp.swift`.
- Add `NoteImage.self` to the `bootstrapDevSchemaIfNeeded` call in `TakeNoteApp.init()`.
- Add `NoteImage.self` to the `ModelContainer(for:)` initializer in `TakeNoteApp.init()`.
- Update `deleteEverything()` in `MainWindow.swift` to also fetch and delete all `NoteImage` records (`@Query() var noteImages: [NoteImage]` added to `MainWindow`).
- Update `data-models.md` to document `NoteImage`.
- Update `architecture.md` to reflect the expanded URL scheme (note vs. image host routing) and the updated component map entry for models.

**Out of scope:**
- Any image insertion UI (toolbar button, drag and drop) — Phase 0012.
- Orphan culling — Phase 0012.
- Any changes to widget or share extension targets.

## Constraints

- **L02:** `NoteImage` is now the fourth permitted `@Model` type. L02 already lists it. No further law changes needed.
- **L03:** Adding `NoteImage` is a schema change. `ckBootstrapVersionCurrent` must be bumped to 10.
- **L12 spirit:** `imageUUID` must have `private(set)`. It is stable across devices.
- **L16/L17/L18/L19:** `data-models.md` and `architecture.md` must be updated and reconciled before phase completion.
- **Style:** `NoteImageStore` follows the inline instantiation pattern of `NoteLinkManager` — a service struct, not an environment-injected object. `TakeNoteImageProvider` is a struct, consistent with MarkdownUI's `ImageProvider` protocol expectations. The `NoteImage` model file starts with the `// Hey! // Hey you!` schema-change reminder comment per style.

## Acceptance criteria

1. `TakeNote/Models/NoteImage.swift` exists with the correct `@Model` definition, `private(set) imageUUID`, and the `// Hey! // Hey you!` comment.
2. `TakeNote/Library/NoteImageStore.swift` exists and `loadImage(uuid:modelContext:)` compiles without error.
3. `TakeNote/Library/TakeNoteImageProvider.swift` exists and conforms to `ImageProvider`.
4. `NoteEditor` preview mode has `.markdownImageProvider(TakeNoteImageProvider(modelContext: modelContext))` applied.
5. `TakeNoteApp.swift`: `ckBootstrapVersionCurrent == 10`, `NoteImage.self` is in both the bootstrap call and the `ModelContainer(for:)` call.
6. `MainWindow.swift`: `onOpenURL` routes image URLs away from `loadNoteFromURL`; `deleteEverything()` deletes `NoteImage` records; `@Query() var noteImages: [NoteImage]` is present.
7. App builds and runs on both macOS and iOS simulators without errors or warnings.
8. `data-models.md` documents the `NoteImage` model with its fields.
9. `architecture.md` reflects the updated URL scheme routing and model list.

## Risks / notes

- CloudKit treats `Data` fields as `CKAsset` automatically for large payloads. No entitlement changes are required.
- The `TakeNoteImageProvider` receives `modelContext` at construction time. In `NoteEditor`, `modelContext` is already available as `@Environment(\.modelContext)`. This is the correct injection point.
- Raw markdown `![image](takenote://image/<UUID>)` will appear as unrendered text in edit mode. This is expected and intentional.
- `imageUUID` stability across devices mirrors `Note.uuid`. SwiftData internal hydration is the only permitted setter invocation.
