//
//  StripMarkdown.swift
//  TakeNote
//

import Foundation

/// Strips common Markdown syntax from text, producing a plain-text version
/// suitable for feeding into search or language-model prompts.
func stripMarkdownForSearch(_ text: String) -> String {
    var s = text
    // Remove images and links but keep link text
    s = s.replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: #"\[([^\]]*)\]\(.*?\)"#, with: "$1", options: .regularExpression)
    // Remove fenced code blocks (``` ... ```)
    s = s.replacingOccurrences(of: #"```[^`]*```"#, with: "", options: .regularExpression)
    // Remove inline code
    s = s.replacingOccurrences(of: #"`[^`]+`"#, with: "", options: .regularExpression)
    // Remove heading markers, bold, italic, strikethrough
    s = s.replacingOccurrences(of: #"#{1,6}\s*"#, with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: #"[*_~]{1,3}"#, with: "", options: .regularExpression)
    // Remove checkbox markers
    s = s.replacingOccurrences(of: #"- \[[ x]\] "#, with: "- ", options: .regularExpression)
    // Collapse multiple blank lines
    s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}
