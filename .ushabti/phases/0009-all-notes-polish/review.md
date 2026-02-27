# Review: Phase 0009 — All Notes Polish

## Summary

All four steps are correctly implemented. Every acceptance criterion is satisfied. Laws and style are observed throughout. Documentation is reconciled. Build was reported as passing. Version bumped to 12 / 1.1.8 by Overseer per L20.

## Verified

### S001 — Sidebar system folder ordering (Sidebar.swift)

- Private file-scope function `systemFolderSortOrder(_ folder: NoteContainer) -> Int` is defined at lines 85–91, returning Inbox→0, Starred→1, AllNotes→2, Trash→3, unknown→4.
- Applied correctly at line 134 inside the `ForEach`: `systemFolders.sorted(by: { systemFolderSortOrder($0) < systemFolderSortOrder($1) })`.
- Function is `lowerCamelCase` and file-scope private, consistent with style.
- AC1 satisfied: deterministic order Inbox, Starred, All Notes, Trash.

### S002 — All Notes note count in NoteListHeader (NoteListHeader.swift)

- `@Query() var allNotes: [Note]` added at line 13.
- `noteCountLabel` at lines 38–44 branches on `container.isAllNotes`: filters `allNotes` excluding Trash and Buffer folders, exactly matching `NoteList.filteredNotes` semantics.
- All other containers fall through to `container.notes.count` — no regression.
- AC2 satisfied: accurate, reactive count for All Notes.

### S003 — Source folder badge in NoteListEntry (NoteListEntry.swift)

- `MetadataRow` condition at lines 230–232: `isTag == true || isStarred == true || isAllNotes == true`. Correctly extended.
- Context menu "Go to Note Folder" guard at lines 410–412: same three-condition guard. Correctly extended.
- AC3 satisfied: folder badge appears when All Notes is selected.
- AC4 satisfied: "Go to Note Folder" context item present and functional under All Notes.
- CommandRegistry `.onAppear` / `.onDisappear` lifecycle is symmetric across all five registries (lines 506–538), satisfying L15.

### S004 — views.md documentation (.ushabti/docs/views.md)

- Sidebar section: explicitly documents `systemFolderSortOrder` with the priority mapping. Accurate.
- NoteListHeader section: documents `@Query() var allNotes`, the `isAllNotes` branch, and the Trash/Buffer filter. Accurate.
- NoteListEntry section: documents `isTag == true || isStarred == true || isAllNotes == true` for both MetadataRow and the context menu guard. Accurate.
- AC6 satisfied. L17, L18, L19 all satisfied.

### Laws and style checks

- **L01:** No `#available` below macOS 26/iOS 26 introduced. Deployment targets unchanged (26.0 in project.pbxproj).
- **L02/L03:** No schema changes; no `ckBootstrapVersionCurrent` bump required. Confirmed.
- **L09:** No new `@Observable` state managers introduced.
- **L11:** `canBeDeleted` on system containers not touched.
- **L15:** CommandRegistry registration and unregistration are symmetric on all five entries in `NoteListEntry`.
- **Style:** Sub-view computed properties on entry views (`TitleRow`, `MetadataRow`, `SummaryRow`, `ContainerNameEditor`, etc.) are `UpperCamelCase`. `systemFolderSortOrder` helper is `lowerCamelCase` file-scope private. `EnvironmentKey` structs are `private`. All consistent.
- **AC5 (no regressions):** Starred, Inbox, Trash, and user folder paths are not modified. The `noteCountLabel` fallback is `container.notes.count` for all non-AllNotes containers. Confirmed.

### Version bump (L20)

- `CURRENT_PROJECT_VERSION` incremented from 11 to 12 (all four occurrences).
- `MARKETING_VERSION` incremented from 1.1.7 to 1.1.8 (all four occurrences).

## Issues

None.

## Required follow-ups

None.

## Decision

**GREEN.** Phase 0009 is complete. All acceptance criteria are satisfied. Laws are observed. Documentation is reconciled. Build succeeds. Version is weighed and found true at 12 / 1.1.8.
