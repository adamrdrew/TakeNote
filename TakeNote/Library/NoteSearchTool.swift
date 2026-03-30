//
//  NoteSearchTool.swift
//  TakeNote
//

import Foundation
import FoundationModels

struct NoteSearchTool: Tool {
    let name = "searchNotes"
    let description = "Search the user's notes. Returns reference material to help you answer — do not repeat or summarize the raw results to the user."

    @Generable
    struct Arguments {
        @Guide(description: "The search query")
        var query: String
    }

    let searchIndex: SearchIndex
    let onSearchStart: @MainActor @Sendable (String) -> Void
    let onResults: @MainActor @Sendable ([SearchHit]) -> Void

    func call(arguments: Arguments) async throws -> String {
        await onSearchStart(arguments.query)
        let hits = searchIndex.searchNatural(arguments.query)
        await onResults(hits)
        guard !hits.isEmpty else { return "No matching notes found." }

        let numbered = hits.enumerated().map { i, hit in
            "[\(i + 1)] \(stripMarkdownForSearch(hit.chunk))"
        }.joined(separator: "\n\n")

        // Use a separate session to filter results for relevance before
        // handing them to the main chat session.
        let filterPrompt = """
            The user asked: "\(arguments.query)"

            Below are search results. Return ONLY the numbers of results that are \
            directly relevant to the user's question. Respond with just the numbers \
            separated by commas, like: 1, 3. If none are relevant respond with: NONE

            \(numbered)
            """

        let filterSession = LanguageModelSession(instructions: "You are a relevance filter. You return only the numbers of relevant results. Nothing else.")
        let filterResponse = try await filterSession.respond(to: filterPrompt)
        let responseText: String = filterResponse.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if responseText.uppercased() == "NONE" {
            return "No matching notes found."
        }

        // Parse the returned indices and keep only matching hits
        let separators = CharacterSet(charactersIn: ", ")
        let parts: [String] = responseText.components(separatedBy: separators)
        let indices: [Int] = parts.compactMap { Int($0.trimmingCharacters(in: CharacterSet.whitespaces)) }
        let valid: [Int] = indices.filter { $0 >= 1 && $0 <= hits.count }

        guard !valid.isEmpty else { return "No matching notes found." }

        var excerpts: [String] = []
        for i in valid {
            let text = stripMarkdownForSearch(hits[i - 1].chunk)
            excerpts.append("---\n\(text)")
        }
        let filtered = excerpts.joined(separator: "\n\n")

        return "Reference material (use to answer the question — do not summarize these):\n\n\(filtered)"
    }
}
