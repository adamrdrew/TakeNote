# Phase 0018: Paste Image Support in NoteEditor

## Intent

Add clipboard image paste support to `NoteEditor` on both macOS and iOS. On macOS, Cmd+V is intercepted via `.onKeyPress` when `NSPasteboard.general` contains image data; if so, `insertImage(data:)` is called and the event is consumed. On iOS, a "Paste Image" toolbar button is added alongside the existing PhotosPicker button; it is enabled only when `UIPasteboard.general.hasImages` is true and tapping it reads clipboard image data and calls `insertImage(data:)`. Both paths are blocked when `showPreview == true`. The existing `insertImage(data:)` entry point is not modified.

This completes the image-insertion surface: images can already enter notes via drag-and-drop and PhotosPicker; paste from clipboard is the remaining standard input channel.

## Scope

**In scope:**
- macOS: `.onKeyPress` intercepting Cmd+V when clipboard contains image data, returning `.handled`; returning `.ignored` otherwise.
- iOS: A new `ToolbarItem` using the `doc.on.clipboard` SF Symbol placed alongside the existing `photo.badge.plus` button, disabled when `showPreview == true` or `UIPasteboard.general.hasImages == false`.
- Both platforms: guarding all paste code paths behind `showPreview == false`.
- Updating `.ushabti/docs/views.md` to document the new paste paths under the NoteEditor image insertion section.

**Out of scope:**
- Any modification to `insertImage(data:)` or `downsize(imageData:)`.
- Any new model types, services, or persistence changes.
- visionOS-specific handling (not a target platform for this feature; conditional compilation blocks will exclude it naturally via `#if os(iOS)`).
- Supporting paste of multiple images in one gesture (single image per paste event is sufficient; clipboard typically holds one image).

## Constraints

- L01: No `#available` checks below macOS 26 / iOS 26. All APIs used (`NSPasteboard`, `UIPasteboard`, `.onKeyPress`) are available at the minimum deployment targets.
- L02/L03: No new `@Model` types; no schema change; no version bump required.
- L09: No new state managers. All state additions are `@State` properties local to `NoteEditor`.
- Style: Platform branching via `#if os(macOS)` / `#if os(iOS)`. `os.Logger` for logging; no `print()` in new code. Toolbar buttons follow existing naming and placement patterns in `NoteEditor`.

## Acceptance criteria

1. On macOS, pressing Cmd+V while the editor is in edit mode (`showPreview == false`) and the clipboard contains image data inserts the image at the caret via `insertImage(data:)` and does not pass the event to CodeEditorView.
2. On macOS, pressing Cmd+V while the editor is in edit mode and the clipboard contains only non-image data (e.g., text) returns `.ignored` and normal paste behavior proceeds.
3. On macOS, pressing Cmd+V while `showPreview == true` takes no image-paste action (the key event is not intercepted).
4. On iOS, the toolbar contains a `doc.on.clipboard` button placed alongside the `photo.badge.plus` button.
5. On iOS, the paste button is disabled when `showPreview == true`.
6. On iOS, when the paste button is tapped and `UIPasteboard.general.hasImages == false`, the action is a no-op (no image is inserted). The button's disabled state is controlled only by `showPreview`; the `hasImages` check is deferred to the action body to avoid spurious iOS privacy prompts.
7. On iOS, tapping the paste button when `UIPasteboard.general.hasImages == true` reads the first available image, converts it to `Data`, and calls `insertImage(data:)`.
8. `.ushabti/docs/views.md` accurately describes the new paste image paths under the NoteEditor image insertion section.

## Risks / notes

- `UIPasteboard.general.hasImages` triggers the iOS privacy banner on access. This is acceptable because access only occurs after the user explicitly taps the toolbar button. The button is not polled continuously.
- On macOS, `.onKeyPress` must be applied at a scope that receives keyboard events when CodeEditorView is focused. Because CodeEditorView wraps `NSTextView`, keyboard focus may not bubble through `.onKeyPress` on the SwiftUI overlay. If `.onKeyPress` on the `ZStack` does not intercept the event, the modifier must be moved to an outer view or a different interception point must be found (see S002 notes). Builder should verify focus receipt and adjust attachment point if needed.
- The macOS implementation reads image data from `NSPasteboard.general.data(forType: .tiff)` first, then `.png` as a fallback, to cover the common clipboard formats before handing to `insertImage(data:)`.
