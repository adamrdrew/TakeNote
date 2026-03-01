//
//  NoteSearchTool.swift
//  TakeNote
//

import FoundationModels

struct NoteSearchTool: Tool {
    let name = "searchNotes"
    let description = "Search the user's notes for relevant information."

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
        return hits.enumerated().map { i, hit in
            "EXCERPT \(i + 1):\n\(stripMarkdownForSearch(hit.chunk))"
        }.joined(separator: "\n\n")
    }
}
