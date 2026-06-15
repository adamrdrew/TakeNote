//
//  TakeNoteShortcuts.swift
//  TakeNote
//

import AppIntents

struct TakeNoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "New note in \(.applicationName)"
            ],
            shortTitle: "New Note",
            systemImageName: "note.text.badge.plus"
        )

        AppShortcut(
            intent: NewNoteWithContentIntent(),
            phrases: [
                "Create a note with \(.applicationName)",
                "Add a note to \(.applicationName)"
            ],
            shortTitle: "New Note With Text",
            systemImageName: "text.badge.plus"
        )

        AppShortcut(
            intent: FindNotesIntent(),
            phrases: [
                "Find notes in \(.applicationName)",
                "Search \(.applicationName)"
            ],
            shortTitle: "Find Notes",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: OpenNoteIntent(),
            phrases: [
                "Open a note in \(.applicationName)",
                "Show a note in \(.applicationName)"
            ],
            shortTitle: "Open Note",
            systemImageName: "note.text"
        )

        AppShortcut(
            intent: AppendToNoteIntent(),
            phrases: [
                "Append to a note in \(.applicationName)",
                "Add text to a note in \(.applicationName)"
            ],
            shortTitle: "Append to Note",
            systemImageName: "text.append"
        )

        AppShortcut(
            intent: CreateFolderIntent(),
            phrases: [
                "Create a folder in \(.applicationName)",
                "New folder in \(.applicationName)"
            ],
            shortTitle: "New Folder",
            systemImageName: "folder.badge.plus"
        )

        AppShortcut(
            intent: CreateTagIntent(),
            phrases: [
                "Create a tag in \(.applicationName)",
                "New tag in \(.applicationName)"
            ],
            shortTitle: "New Tag",
            systemImageName: "tag"
        )
    }
}
