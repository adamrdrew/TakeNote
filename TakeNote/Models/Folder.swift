
//
//  File.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//
import SwiftData
import SwiftUI

@Model
class Folder : Identifiable {
    var name: String
    var notes : [Note] = []
    internal var canBeDeleted: Bool = true
    
    init(canBeDeleted: Bool = true, name: String = "New Folder") {
        self.name = name
        self.canBeDeleted = canBeDeleted
    }
}
