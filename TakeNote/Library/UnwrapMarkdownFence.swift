//
//  UnwrapMarkdownFence.swift
//  TakeNote
//
//  Created by Adam Drew on 8/18/25.
//


func unwrapMarkdownFence(_ input: String) -> String {
    // Trim off surrounding whitespace/newlines first
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

    // Must start with ```
    guard trimmed.hasPrefix("```") else { return input }
    // Find the first newline after the opening fence
    guard let firstNewline = trimmed.firstIndex(of: "\n") else { return input }

    // Opening fence line (could be ```markdown, ```bash, or just ```)
    let openingFence = String(trimmed[..<firstNewline])
    guard openingFence.starts(with: "```") else { return input }

    // Must end with ```
    guard trimmed.hasSuffix("```") else { return input }

    // Slice off the top and bottom lines
    let startOfBody = trimmed.index(after: firstNewline)
    let endOfBody = trimmed.index(trimmed.endIndex, offsetBy: -3) // chop off ```
    let body = trimmed[startOfBody..<endOfBody]

    // Return body, trimmed of one trailing newline (since fences usually add one)
    return body.trimmingCharacters(in: .newlines)
}
