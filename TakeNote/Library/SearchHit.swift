//
//  SearchHit.swift
//  TakeNote
//
//  Created by Adam Drew on 9/5/25.
//

import Foundation

struct SearchHit: Identifiable {
    public let id: Int64  // rowid inside FTS table
    public let noteID: UUID
    public let chunk: String  // the stored chunk text
}
