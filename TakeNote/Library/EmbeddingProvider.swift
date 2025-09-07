//
//  EmbeddingProvider.swift
//  TakeNote
//
//  Created by Adam Drew on 9/7/25.
//


//
//  EmbeddingProvider.swift
//  TakeNote
//
//  Created by Adam Drew on 9/5/25.
//

import NaturalLanguage

class EmbeddingProvider {
    private let model: NLEmbedding?
    private let dim: Int?

    init(language: NLLanguage = .english, revision: Int? = nil) {
        if let rev = revision {
            self.model = NLEmbedding.sentenceEmbedding(for: language, revision: rev)
        } else {
            self.model = NLEmbedding.sentenceEmbedding(for: language)
        }
        self.dim = model?.dimension
    }

    /// Returns a unit-length Float vector or nil if unavailable
    func embed(_ text: String) -> [Float]? {
        guard let model else { return nil }
        guard let v = model.vector(for: text) else { return nil } // [Double]
        var f = v.map { Float($0) }
        // L2 normalize
        let norm = sqrt(max(1e-12, f.reduce(0) { $0 + $1*$1 }))
        for i in 0..<f.count { f[i] /= norm }
        // Optional: ensure consistent dimension
        if let dim, f.count != dim { return nil }
        return f
    }
}
