# Phase 0001: Hygiene Fixes

## Intent

Fix three low-risk, isolated code quality issues identified in the audit: a typo in the `SearchIndexService` logger subsystem string (R001), `MagicFormatter` using the deprecated `ObservableObject`/`@Published` pattern instead of `@Observable` (R002), and production `print()` calls outside `#if DEBUG` guards across five files (R006). None of these issues affect correctness on paths that are currently reachable, but they produce incorrect observability data (wrong subsystem in Console), block Swift 6 strict-concurrency alignment, and leave debug noise in production logs.

## Scope

**In scope:**
- Fix the `com.adammdrew.takenote` → `com.adamdrew.takenote` subsystem typo in `SearchIndexService.logger` (R001)
- Migrate `MagicFormatter` from `ObservableObject`/`@Published` to `@Observable`; update any call sites that use `@StateObject` or `@ObservedObject` to use `@State` (R002)
- Wrap or replace `print()` calls in `TakeNoteVM.swift` (line 157), `CommandRegistry.swift` (line 32), `SystemFolderReconciler.swift` (line 63), `NoteLinkManager.swift` (line 140), and `EditCommands.swift` (line 124) with appropriate `os.Logger` calls or remove them entirely (R006)

**Out of scope:**
- Changing any behavior or logic in the affected files beyond what is required for the three fixes
- Fixing R004, R005, R007, R009, R010, R011 — those are handled in subsequent phases

## Constraints

- Style: `@Observable @MainActor` is the required pattern for service objects (style guide, "Architectural Patterns — Preferred")
- Style: Logging must use `os.Logger` with subsystem `com.adamdrew.takenote`; `print()` must not be introduced in new code
- Style: `@StateObject` and `@ObservedObject` are discouraged; `@State` is the correct property wrapper for `@Observable` types in SwiftUI
- L09: `TakeNoteVM` is the sole app-wide state manager; `MagicFormatter` is a scoped view-level object so converting it to `@Observable` does not violate L09
- L05, L06: `MagicFormatter` must continue to create a fresh `LanguageModelSession` per call; the `@Observable` migration must not change this behavior

## Acceptance criteria

- `SearchIndexService.logger` subsystem is `"com.adamdrew.takenote"` (single 'm')
- `MagicFormatter` is declared `@Observable class MagicFormatter` with no `ObservableObject` conformance and no `@Published` annotations; properties that were `@Published` are plain `var`
- `NoteEditor` uses `@State private var magicFormatter = MagicFormatter()` (not `@StateObject`)
- The project builds without warnings related to `ObservableObject` or `@Published` in `MagicFormatter`
- No `print()` calls exist in production code paths in the five named files outside `#if DEBUG` blocks
- Replacement log calls use `os.Logger` with the correct subsystem
- `CommandRegistry.runCommand` retains its debug-trace intent but uses `logger.debug(...)` instead of `print()`
- The project builds successfully and MagicFormatter continues to function correctly

## Risks / notes

- `MagicFormatter` uses `@StateObject` in `NoteEditor`. Changing to `@State` changes initialization semantics slightly: `@StateObject` guarantees the object is created once per view identity, while `@State` with a class wrapped in `@Observable` has the same guarantee since SwiftUI tracks `@State` by identity. This is safe.
- `MagicFormatter` has `@Published var formatterIsBusy` and `@Published var sessionCancelled`. After migration these become plain `var` on an `@Observable` class, which `@Observable` tracks automatically. The `$formatterIsBusy` binding used in `NoteEditor` (for the `.sheet(isPresented:)` modifier) becomes a direct `$magicFormatter.formatterIsBusy` binding.
- `EditCommands.swift` line 124 is a `print("EditMenu.copyMarkdownLink")` inside a `Commands` struct. `Commands` structs do not have direct access to a `Logger` instance. The appropriate fix is either to add a file-scoped `Logger` constant or to remove the print entirely, since it is purely a debug trace.
