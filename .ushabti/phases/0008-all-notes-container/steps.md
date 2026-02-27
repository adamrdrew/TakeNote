# Steps

## S001: Add `isAllNotes` field to `NoteContainer` and update `isSystemFolder`

**Intent:** Establish the schema-level identity flag for the All Notes container, following the exact same pattern as `isTrash`, `isInbox`, `isStarred`, and `isBuffer`.

**Work:**
- In `TakeNote/Models/NoteContainer.swift`, add `internal var isAllNotes: Bool = false` alongside the other boolean flags (after `isBuffer`).
- Update the `isSystemFolder` computed property to include `|| isAllNotes`.
- The `notes` computed property requires no change (All Notes uses a view-level cross-container query, not a relationship array).
- The `getSystemImageName()` method requires no change (falls through to `symbol` correctly).

**Done when:** `NoteContainer` compiles with the new field; `isSystemFolder` returns `true` for a container where `isAllNotes == true`.

---

## S002: Bump `ckBootstrapVersionCurrent` in `TakeNoteApp.swift`

**Intent:** Fulfill L03 — any persisted field addition to a SwiftData model must increment the schema version so CloudKit bootstrapping re-runs on DEBUG launch.

**Work:**
- In `TakeNote/TakeNoteApp.swift`, increment `ckBootstrapVersionCurrent` by 1 (current value is `8`; new value is `9`).

**Done when:** `ckBootstrapVersionCurrent` reads `9`.

---

## S003: Add `allNotesFolder` property and `createAllNotesFolder` to `TakeNoteVM`

**Intent:** Give `TakeNoteVM` a reference to the All Notes container and the ability to create it idempotently on startup, following the same pattern as `createInboxFolder`, `createTrashFolder`, `createBufferFolder`, and `createStarredFolder`.

**Work:**
- In `TakeNote/TakeNoteVM.swift`:
  - Add `static let allNotesFolderName = "All Notes"` alongside the other name constants.
  - Add `var allNotesFolder: NoteContainer?` alongside `inboxFolder`, `trashFolder`, `bufferFolder`, `starredFolder`.
  - Add `createAllNotesFolder(_ modelContext: ModelContext)` method. It must:
    - Guard on `self.allNotesFolder != nil` (return early if already exists).
    - Create a `NoteContainer` with `canBeDeleted: false`, `isAllNotes` set to `true` via direct property assignment (same pattern as `createBufferFolder` which sets `bufferFolder.isBuffer = true` after init), `name: TakeNoteVM.allNotesFolderName`, `symbol: "text.pad.header"`.
    - Insert, save, assign `self.allNotesFolder`.
  - Call `createAllNotesFolder(modelContext)` from `folderInit(_:)`.
  - Update `canAddNote` to also return `false` when `selectedContainer?.isAllNotes == true`.
  - Update `canRenameSelectedContainer` to also return `false` when `sc.isAllNotes == true`.

**Done when:** `TakeNoteVM` compiles with the new property, constant, and method; `folderInit` calls `createAllNotesFolder`; `canAddNote` and `canRenameSelectedContainer` are blocked for All Notes.

---

## S004: Extend `SystemFolderReconciler` to reconcile the All Notes container

**Intent:** Fulfill L11 — all system containers must be reconciled on every `NSPersistentStoreRemoteChange` to handle CloudKit-induced duplicates. The reconciler must also update `TakeNoteVM.allNotesFolder` after reconciliation.

**Work:**
- In `TakeNote/Library/SystemFolderReconciler.swift`, in `runOnce()`:
  - Add `let allNotes = try reconcile(match: #Predicate { $0.isAllNotes })`.
  - Add `vm.allNotesFolder = allNotes ?? fetchSingle(#Predicate { $0.isAllNotes })` after the other `vm.xFolder` assignments.
  - No changes to `reconcile()` or `chooseCanonical()` are needed — they are generic.

**Done when:** `SystemFolderReconciler.runOnce()` reconciles All Notes duplicates and updates `vm.allNotesFolder`.

---

## S005: Update Sidebar queries and FolderList guard

**Intent:** Ensure the All Notes container appears in the system folders section of the Sidebar and is excluded from the user folders section and from `FolderList`.

**Work:**
- In `TakeNote/Views/MainWindow/Sidebar.swift`:
  - `systemFolders` `@Query` predicate: add `|| folder.isAllNotes` so it reads `folder.isTrash || folder.isInbox || folder.isStarred || folder.isAllNotes`.
  - `folders` `@Query` predicate: add `&& !folder.isAllNotes` so it reads `!folder.isTag && !folder.isTrash && !folder.isInbox && !folder.isBuffer && !folder.isAllNotes`.
- In `TakeNote/Views/FolderList/FolderList.swift`:
  - Add `|| folder.isAllNotes` to the existing guard condition so it reads `folder.isBuffer || folder.isInbox || folder.isTag || folder.isTrash || folder.isStarred || folder.isAllNotes`.

**Done when:** All Notes appears in the Sidebar system folders section; it does not appear in the Folders section or as a `FolderListEntry`.

---

## S006: Implement cross-container note list in `NoteList` for All Notes

**Intent:** When All Notes is selected, `filteredNotes` must return all notes from all non-system-folder origins (i.e., notes not in Trash or Buffer), sourced from the view-level `@Query var notes: [Note]` which already fetches every note in the store.

**Work:**
- In `TakeNote/Views/NoteList/NoteList.swift`, update `filteredNotes`:
  - Add a branch: if `takeNoteVM.selectedContainer?.isAllNotes == true`, return all notes from `notes` (the `@Query` result) that are not in Trash and not in Buffer — specifically, notes where `note.folder?.isTrash != true && note.folder?.isBuffer != true`. Apply the `noteSearchText` filter the same way as the existing branch.
  - The existing branch (using `takeNoteVM.selectedContainer?.notes`) remains unchanged for all other containers.

**Done when:** Selecting All Notes in the Sidebar displays notes from all non-trash, non-buffer folders; the search bar filters the list correctly.

---

## S007: Update documentation

**Intent:** Fulfill L17 — Builder must update docs when code changes affect documented systems. The All Notes container touches the data model, view model, and supporting systems documentation.

**Work:**
- In `.ushabti/docs/data-models.md`:
  - Add `isAllNotes` row to the `NoteContainer` fields table.
  - Add an All Notes row to the System Containers table.
  - Update the `isSystemFolder` description to note it includes `isAllNotes`.
- In `.ushabti/docs/view-model.md`:
  - Add `allNotesFolder` to the System Folder References table.
  - Add `allNotesFolderName` to the Constants table.
  - Add `createAllNotesFolder(_:)` to the System Folder Creation method list.
  - Update `canAddNote` and `canRenameSelectedContainer` descriptions to reflect All Notes blocking.
- In `.ushabti/docs/supporting-systems.md`:
  - Update `SystemFolderReconciler.runOnce()` description to mention All Notes reconciliation.

**Done when:** All three documentation files accurately reflect the new container.
