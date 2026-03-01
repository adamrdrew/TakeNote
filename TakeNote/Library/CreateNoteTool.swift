//
//  CreateNoteTool.swift
//  TakeNote
//

import Foundation
import FoundationModels

struct CreateNoteTool: Tool {
    let name = "createNote"
    let description = "Create a new note in the user's Inbox."

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note")
        var title: String
        @Guide(description: "The markdown content of the note")
        var content: String
    }

    let onStatusChange: @MainActor @Sendable (String?) -> Void
    let onCreate: @MainActor @Sendable (String, String) async -> UUID?

    func call(arguments: Arguments) async throws -> String {
        await onStatusChange("Creating note...")
        guard await onCreate(arguments.title, arguments.content) != nil else {
            await onStatusChange("Failed to create note")
            return "Failed to create note."
        }
        await onStatusChange("Note created")
        return "Note created: \(arguments.title)"
    }
}
