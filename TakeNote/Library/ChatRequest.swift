import Foundation

/// Builds a turn independently of the model's hidden transcript so changing tools
/// cannot discard the conversation or authorize a write from an earlier request.
enum ChatRequest {
    static func allowsNoteCreation(_ prompt: String) -> Bool {
        let pattern = #"^\s*(?:please\s+)?(?:(?:can|could|would|will)\s+you\s+)?(?:please\s+)?(?:create|make|save|draft|write|add|start|compose)\s+(?:(?:me|us|this|that|it|these|those|as|to|a|an|the|new|another|my|some|markdown)\s+){0,8}(?:note|notes|markdown)\b"#
        return prompt.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func prompt(_ question: String, context: String?, history: [ConversationEntry]) -> String {
        var sections: [String] = []
        if !history.isEmpty {
            let transcript = history.map { entry in
                "\(entry.sender == .human ? "User" : "Assistant"): \(entry.text)"
            }.joined(separator: "\n\n")
            sections.append("Earlier conversation (for reference):\n\(transcript)")
        }
        if let context {
            sections.append("CONTEXT:\n\(context)")
        }
        sections.append("Current request:\n\(question)")
        return sections.joined(separator: "\n\n")
    }
}
