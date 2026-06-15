//
//  FocusValues.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

import SwiftData
import SwiftUI

extension FocusedValues {
    @Entry var modelContext: ModelContext?
    @Entry var chatEnabled: Bool?
    @Entry var mainWindowActions: MainWindowActions?
    @Entry var noteEditorActions: NoteEditorActions?

    @Entry var containerDeleteRegistry: CommandRegistry?
    @Entry var containerRenameRegistry: CommandRegistry?
    @Entry var selectedNoteContainer: NoteContainer?
    @Entry var tagSetColorRegistry: CommandRegistry?

    @Entry var noteDeleteRegistry: CommandRegistry?
    @Entry var noteRenameRegistry: CommandRegistry?
    @Entry var noteStarToggleRegistry: CommandRegistry?
    @Entry var noteCopyMarkdownLinkRegistry: CommandRegistry?
    @Entry var noteOpenEditorWindowRegistry: CommandRegistry?
    @Entry var selectedNotes: Set<Note>?
}

extension EnvironmentValues {
    @Entry var containerDeleteRegistry: CommandRegistry?
    @Entry var containerRenameRegistry: CommandRegistry?
    @Entry var tagSetColorRegistry: CommandRegistry?

    @Entry var noteDeleteRegistry: CommandRegistry?
    @Entry var noteCopyMarkdownLinkRegistry: CommandRegistry?
    @Entry var noteRenameRegistry: CommandRegistry?
    @Entry var noteStarToggleRegistry: CommandRegistry?
    @Entry var noteOpenEditorWindowRegistry: CommandRegistry?
}
