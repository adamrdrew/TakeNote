//
//  UnwrapMarkdownFence.swift
//  TakeNote
//
//  Created by Adam Drew on 8/18/25.
//

import AppKit

func unwrapMarkdownFence(_ input: String) -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

    // Regex: triple backticks + optional language + newline … newline + triple backticks
    let pattern = #"^\s*```(?:[a-zA-Z0-9_-]+)?\s*\n([\s\S]*?)\n```s*\z"#

    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
          let bodyRange = Range(match.range(at: 1), in: trimmed) else {
        return input // not a fully wrapped fence → return untouched
    }

    return String(trimmed[bodyRange])
}
