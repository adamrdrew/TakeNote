//
//  Note.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

@Model
class Note : Identifiable {
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    
    init() {
        self.title = "New Note"
        self.content = ""
        self.createdDate = Date()
    }
}
