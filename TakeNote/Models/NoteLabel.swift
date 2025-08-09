//
//  Label.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftUI
import SwiftData

@Model
class NoteLabel : Identifiable {
    var name: String = "New Tag"
    var normalizedName : String = ""
    var notes : [Note] = []
    var color : String = "blue"
    
    
    init(name: String, color: String) {
        self.name = name
        self.normalizedName = makeNormalizedName()
        self.notes = []
        self.color = color
    }
    
    public func rename (to newName: String) {
        if newName != name {
            self.name = newName
            self.normalizedName = makeNormalizedName()
        }
    }
    
    private func makeNormalizedName() -> String {
        return name.replacingOccurrences(of: " ", with: "-").lowercased()
    }
    
}
