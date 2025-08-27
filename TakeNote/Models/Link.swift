//
//  Link.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftData
import SwiftUI

@Model
class Link {
    var sourceNote: Note
    var destinationNote: Note
    
    init(sourceNote: Note, destinationNote: Note) {
        self.sourceNote = sourceNote
        self.destinationNote = destinationNote
    }
}
