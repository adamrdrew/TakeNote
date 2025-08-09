//
//  Label.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftUI
import SwiftData

@Model
class Label : Identifiable {
    var name: String = "New Tag"
    var color: Color = Color.blue
    var notes : Set<Note> = []
    
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
    }
    
}
