//
//  CreateNoteTool.swift
//  TakeNote
//

import Foundation
import FoundationModels

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
