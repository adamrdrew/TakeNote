# Steps

## S001: Add `isArchive` field to `NoteContainer` and bump schema version

**Intent:** Introduce the `isArchive` discriminator flag on `NoteContainer`, following the exact pattern of existing system folder flags. Update `isSystemFolder` to include archive. Bump `ckBootstrapVersionCurrent` per L03.

**Work:**
- In `TakeNote/Models/NoteContainer.swift`: add `internal var isArchive: Bool = false` alongside the other boolean flags.
- Update `isSystemFolder` computed property: `isTrash || isInbox || isStarred || isAllNotes || isArchive`.
- In `TakeNote/TakeNoteApp.swift`: increment `ckBootstrapVersionCurrent` by 1 (current value is 10, new value is 11).

**Done when:** `NoteContainer` has `isArchive`, `isSystemFolder` returns `true` for archive containers, and `ckBootstrapVersionCurrent` is 11.

---

## S002: Add `archiveFolder` property and archive methods to `TakeNoteVM`

**Intent:** Give `TakeNoteVM` the archive folder reference, creation method, and move method, following the exact patterns of `inboxFolder`/`createInboxFolder`/`moveNoteToTrash`.

**Work:**
- Add `var archiveFolder: NoteContainer?` to the system folder references group in `TakeNoteVM`.
- Add static constant `static let archiveFolderName = "Archive"`.
- Add `func createArchiveFolder(_ modelContext: ModelContext)` — idempotent, guards on `archiveFolder != nil`, creates a `NoteContainer` with `canBeDeleted: false`, `name: archiveFolderName`, `symbol: "archivebox"`, then sets `isArchive = true` on it.
- Add `func moveNoteToArchive(_ note: Note, modelContext: ModelContext)` — moves the note to `archiveFolder` via `note.setFolder(archiveFolder!)`, then saves.
- Update `canAddNote` to also return `false` when `selectedContainer?.isArchive == true`.
- Update `canRenameSelectedContainer` to also return `false` when `sc.isArchive`.
- Update `folderInit` to call `createArchiveFolder(modelContext)` alongside the other system folder creation calls.

**Done when:** `TakeNoteVM` compiles with all new properties and methods; `canAddNote` and `canRenameSelectedContainer` guard archive correctly; `folderInit` creates the archive folder.

---

## S003: Update `SystemFolderReconciler` to reconcile the archive folder

**Intent:** Ensure CloudKit-induced duplicate archive folders are merged, exactly as the other system folders are.

**Work:**
- In `TakeNote/Library/SystemFolderReconciler.swift`, add an archive reconcile call in `runOnce()`:
  ```swift
  let archive = try reconcile(match: #Predicate { $0.isArchive })
  ```
  Place it after the `allNotes` line.
- Add the VM assignment:
  ```swift
  vm.archiveFolder = archive ?? fetchSingle(#Predicate { $0.isArchive })
  ```
  Place it after `vm.allNotesFolder = ...`.

**Done when:** `SystemFolderReconciler.runOnce()` reconciles all six system folder types including archive, and `vm.archiveFolder` is updated after reconciliation.

---

## S004: Update `Sidebar.swift` queries and sort order for the archive folder

**Intent:** Make the archive folder appear in the system folders section of the sidebar (after Trash), and exclude it from the user folders section.

**Work:**
- Update the `systemFolders` `@Query` filter predicate to add `|| folder.isArchive`:
  ```swift
  folder.isTrash || folder.isInbox || folder.isStarred || folder.isAllNotes || folder.isArchive
  ```
- Update the `folders` `@Query` filter predicate to add `&& !folder.isArchive`:
  ```swift
  !folder.isTag && !folder.isTrash && !folder.isInbox
      && !folder.isBuffer && !folder.isAllNotes && !folder.isArchive
  ```
- Update `systemFolderSortOrder` to assign sort order 4 to archive (after Trash at 3):
  ```swift
  if folder.isArchive { return 4 }
  ```
  The existing `return 4` fallback (unknown) should become `return 5`.

**Done when:** Archive appears in the sidebar's system folders section below Trash; user folders section excludes archive; sort order is deterministic.

---

## S005: Exclude archived notes from search reindex in `AppBootstrapper.swift`

**Intent:** Archived notes must not be indexed by the search system. Both bulk reindex call sites in `AppBootstrapper` build a note list from a full `FetchDescriptor<Note>` fetch — each must filter out notes whose folder is the archive.

**Work:**
- In `AppBootstrapper.installReconciler`, in the `NSPersistentStoreRemoteChange` handler block, change:
  ```swift
  searchIndexService.reindexAll(n.map { note in (note.uuid, note.content) })
  ```
  to:
  ```swift
  searchIndexService.reindexAll(n.filter { $0.folder?.isArchive != true }.map { note in (note.uuid, note.content) })
  ```
- Apply the same filter to the startup reindex block inside `if runOnStartup`.

**Done when:** Both `reindexAll` call sites in `AppBootstrapper` exclude archived notes.

---

## S006: Exclude archived notes from `NoteList.swift` reindex and All Notes view

**Intent:** Archived notes must not appear in All Notes and must not be submitted to bulk reindex from `NoteList`.

**Work:**
- In `NoteList.filteredNotes`, update `allNotesSource` to also exclude archived notes:
  ```swift
  let allNotesSource = notes.filter {
      $0.folder?.isTrash != true && $0.folder?.isBuffer != true && $0.folder?.isArchive != true
  }
  ```
- In `NoteList.body`, update the `onChange(of: notes.count)` handler to exclude archived notes from the reindex payload:
  ```swift
  search.reindexAll(notes.filter { $0.folder?.isArchive != true }.map { ($0.uuid, $0.content) })
  ```

**Done when:** All Notes view does not show archived notes; note count change reindex excludes archived notes.

---

## S007: Add archive swipe action and context menu item to `NoteListEntry.swift`

**Intent:** Give users the ability to archive notes via leading-edge swipe (all platforms) and context menu (all platforms). The actions are guarded so they do not appear when the note is already in archive or trash.

**Work:**
- Add `func archiveNote()` to `NoteListEntry`:
  ```swift
  func archiveNote() {
      takeNoteVM.moveNoteToArchive(note, modelContext: modelContext)
      search.deleteFromIndex(noteID: note.uuid)
  }
  ```
- Add a leading-edge swipe action outside the existing `#if os(iOS)` block (so it applies on all platforms):
  ```swift
  .swipeActions(edge: .leading) {
      if note.folder?.isArchive != true && note.folder?.isTrash != true {
          Button(action: { archiveNote() }) {
              Label("Archive", systemImage: "archivebox")
          }
          .tint(.blue)
      }
  }
  ```
  Place this after the trailing swipe block and before the `#if os(iOS)` leading swipe block.
- Add a context menu item "Move to Archive" inside the existing `.contextMenu` block, near the "Move to Trash" item. Guard it: only show when `note.folder?.isArchive != true && note.folder?.isTrash != true`:
  ```swift
  if note.folder?.isArchive != true && note.folder?.isTrash != true {
      Button(action: { archiveNote() }) {
          Label("Move to Archive", systemImage: "archivebox")
      }
  }
  ```

**Done when:** On all platforms, a leading swipe on a non-archived, non-trashed note shows a blue Archive action. The context menu shows "Move to Archive" on non-archived, non-trashed notes. Neither action appears when already in archive or trash. Archiving a note removes it from the search index and moves it to the archive folder.

---

## S008: Update documentation

**Intent:** Keep `.ushabti/docs/` accurate with all code changes made in this phase (L17, L18, L19).

**Work:**
- `data-models.md`: Add `isArchive` to the `NoteContainer` fields table; update `isSystemFolder` description; update the System Containers table to include the Archive row.
- `view-model.md`: Add `archiveFolder` to the system folder references table; add `archiveFolderName` constant; document `createArchiveFolder` and `moveNoteToArchive` methods; update `canAddNote` and `canRenameSelectedContainer` descriptions.
- `supporting-systems.md`: Update `SystemFolderReconciler.runOnce()` description to mention archive reconciliation (six types, not five).
- `views.md`: Update `Sidebar` section to reflect the new `isArchive` filter additions; update `NoteListEntry` section to document the archive swipe action and context menu item; update `NoteList` section to reflect the archive exclusion in `allNotesSource` and `onChange` reindex.

**Done when:** All four docs files accurately reflect the post-phase code. No doc references five system folder types without mentioning archive. The `isArchive` field is documented in the data model.
