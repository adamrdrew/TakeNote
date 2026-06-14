//
//  NoteSearchTool.swift
//  TakeNote
//

import Foundation
import FoundationModels
import Reductio

struct NoteSearchTool: Tool {
    let name = "searchNotes"
    let description = "Search the user's notes. Returns reference material to help you answer — do not repeat or summarize the raw results to the user."

    @Generable
    struct Arguments {
        @Guide(description: "A focused query for searching the user's notes. Prefer important nouns, names, dates, and phrases.")
        var query: String
    }

    @Generable
    struct RelevanceFilterResult {
        @Guide(description: "The 1-based numbers of search results that directly answer or support the user's question. Return an empty array when none are relevant.")
        var relevantResultNumbers: [Int]
    }

    let search: SearchIndexService
    let onSearchStart: @MainActor @Sendable (String) -> Void
    let onResults: @MainActor @Sendable ([SearchHit]) -> Void

    /// Use TextRank to compress a chunk down to its most important sentences.
    private func summarizeChunk(_ text: String) -> String {
        let plain = stripMarkdownForSearch(text)
        let sentences = plain.summarize(count: 3)
        if sentences.isEmpty { return String(plain.prefix(500)) }
        return sentences.joined(separator: " ")
    }

    func call(arguments: Arguments) async throws -> String {
        await onSearchStart(arguments.query)
        let hits = await search.search(arguments.query)
        guard !hits.isEmpty else { return "No matching notes found." }

        // Compress chunks via TextRank before sending to the relevance filter.
        // This produces denser text for both the filter and the main model.
        let numbered = hits.enumerated().map { i, hit in
            "[\(i + 1)] \(summarizeChunk(hit.chunk))"
        }.joined(separator: "\n\n")

        // Use a separate session to filter results for relevance before
        // handing them to the main chat session.
        let filterPrompt = """
            The user asked: "\(arguments.query)"

            Below are numbered search results from the user's private notes.
            Select only the results that directly answer the question or provide necessary supporting evidence.
            Do not select loosely related results.

            \(numbered)
            """

        let filterSession = LanguageModelSession(
            profile: TakeNoteLanguageModels.profile(
                instructions: "You are a strict relevance filter for private note search results.",
                model: TakeNoteLanguageModels.contentTagging,
                maximumResponseTokens: 64
            )
        )
        let filterResponse = try await filterSession.respond(
            to: TakeNoteLanguageModels.prompt(filterPrompt),
            generating: RelevanceFilterResult.self
        )
        let valid = filterResponse.content.relevantResultNumbers.filter { $0 >= 1 && $0 <= hits.count }

        guard !valid.isEmpty else { return "No matching notes found." }

        let filteredHits = valid.map { hits[$0 - 1] }
        await onResults(filteredHits)

        // Return the compressed excerpts for relevant hits
        var excerpts: [String] = []
        for hit in filteredHits {
            excerpts.append("---\n\(summarizeChunk(hit.chunk))")
        }
        let filtered = excerpts.joined(separator: "\n\n")

        return "Reference material (use to answer the question — do not summarize these):\n\n\(filtered)"
    }
}
