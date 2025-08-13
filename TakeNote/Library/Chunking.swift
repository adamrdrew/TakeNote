import Foundation

public struct NoteChunk {
    public let text: String
    public init(_ text: String) { self.text = text }
}

/// Splits text into ~maxChars windows at whitespace. If short, returns one chunk.
public struct WindowChunker {
    public let maxChars: Int
    public init(maxChars: Int = 1000) { self.maxChars = maxChars }

    public func chunks(for markdown: String) -> [NoteChunk] {
        guard markdown.count > maxChars else { return [NoteChunk(markdown)] }
        var out: [NoteChunk] = []
        var start = markdown.startIndex

        while start < markdown.endIndex {
            let hardEnd = markdown.index(start, offsetBy: maxChars, limitedBy: markdown.endIndex) ?? markdown.endIndex
            var cut = hardEnd
            var i = hardEnd
            while i > start {
                let p = markdown.index(before: i)
                if markdown[p].isWhitespace || markdown[p].isNewline { cut = i; break }
                i = p
            }
            out.append(NoteChunk(String(markdown[start..<cut])))
            start = cut
        }
        return out
    }
}
