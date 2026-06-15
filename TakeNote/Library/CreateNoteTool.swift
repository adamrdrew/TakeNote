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
    let description = "Create a new Markdown note in the user's Inbox when the user explicitly asks to create or save one."

    @Generable
    struct Arguments {
        @Guide(description: "A concise note title without Markdown formatting.")
        var title: String
        @Guide(description: "The note body in clean Markdown. Include only content the user requested or supplied.")
        var content: String
    }

    let onStatusChange: @MainActor @Sendable (ToolCallStatus?) -> Void
    let onCreate: @MainActor @Sendable (String, String) async -> UUID?

    func call(arguments: Arguments) async throws -> String {
        await onStatusChange(.creatingNote)
        guard await onCreate(arguments.title, arguments.content) != nil else {
            await onStatusChange(.failedToCreateNote)
            return "Failed to create note."
        }
        await onStatusChange(.noteCreated)
        return "Note created: \(arguments.title)"
    }
}
