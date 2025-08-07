
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
    internal var isTrash: Bool = false
    internal var isInbox: Bool = false
    var symbol: String = "folder"
    
    init(canBeDeleted: Bool = true, isTrash: Bool = false, isInbox: Bool = false, name: String = "New Folder", symbol: String = "folder" ) {
        self.name = name
        self.canBeDeleted = canBeDeleted
        self.isTrash = isTrash
        self.isInbox = isInbox
        self.symbol = symbol
    }
    
    
    func getSystemImageName() -> String {
        if isTrash && notes.isEmpty {
            return "trash"
        }
        if isTrash && !notes.isEmpty {
            return "trash.fill"
        }
        if isInbox && notes.isEmpty {
            return "tray"
        }
        if isInbox && !notes.isEmpty {
            return "tray.fill"
        }
        return symbol
    }
    
}
