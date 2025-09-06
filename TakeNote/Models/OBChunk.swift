//
//  OBChunk.swift
//  TakeNote
//
//  Created by Adam Drew on 9/5/25.
//

import Foundation
import ObjectBox

/// A question I had was the dimensionality of the apple NLEmbedding sentence embeddings
/// I can find no official source stating what they are
/// Google's AI claims they are a fixed 512 size. I have no idea if this is true

// objectbox: entity
class OBChunk {
    var id: Id = 0

    var noteID: String = ""
    
    var chunk: String = ""
    
    // objectbox:hnswIndex: dimensions=512, distanceType="cosine"
    var embedding: [Float]?
    
    init() {}
    
    init(id: Id = 0, noteID: UUID, chunk: String, embedding: [Float]?) {
        self.noteID = noteID.uuidString
        self.chunk = chunk
        self.embedding = embedding
    }
}
