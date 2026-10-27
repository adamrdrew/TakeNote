//
//  CreateNoteTool.swift
//  TakeNote
//

import Foundation
import FoundationModels

enum ToolCallStatus: Hashable, Sendable {
    case searchingNotes
    case noResultsFound
    case foundResults(Int)
    case creatingNote
    case failedToCreateNote
    case noteCreated

    var message: LocalizedStringResource {
        switch self {
        case .searchingNotes:
            "Searching notes..."
        case .noResultsFound:
            "No results found"
        case .foundResults(1):
            "Found 1 result"
        case .foundResults(let count):
            "Found \(count) results"
        case .creatingNote:
            "Creating note..."
        case .failedToCreateNote:
            "Failed to create note"
        case .noteCreated:
            "Note created"
        }
    }

    var iconName: String {
        switch self {
        case .searchingNotes, .noResultsFound, .foundResults:
            "magnifyingglass"
        case .creatingNote, .noteCreated:
            "note.text.badge.plus"
        case .failedToCreateNote:
            "exclamationmark.triangle"
        }
    }
}

struct CreateNoteTool: Tool {
    let name = "createNote"
    let description = "Create a new Markdown note in the user's Inbox. Use only for explicit requests to create, save, draft, write, add, compose, or start a new note. Never use for questions, searches, summaries, or requests to find existing notes."

    @Generable
    struct Arguments {
        @Guide(description: "A concise title for the new note. Do not infer a title for existing-note questions or searches.")
        var title: String
        @Guide(description: "The new note body in clean Markdown. Include only content the user explicitly requested or supplied for a new note.")
        var content: String
    }

    let onStatusChange: @MainActor @Sendable (ToolCallStatus?) -> Void
    let onCreate: @MainActor @Sendable (String, String) async -> UUID?

    func call(arguments: Arguments) async throws -> String {
        try Task.checkCancellation()
        await onStatusChange(.creatingNote)
        guard await onCreate(arguments.title, arguments.content) != nil else {
            await onStatusChange(.failedToCreateNote)
            return "Failed to create note."
        }
        await onStatusChange(.noteCreated)
        return "Note created: \(arguments.title)"
    }
}
