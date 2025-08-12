//
//  NoteContainer.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//
import SwiftData
import SwiftUI

@Model
class NoteContainer: Identifiable {
    var name: String
    var folderNotes: [Note] = []
    var tagNotes: [Note] = []
    internal var canBeDeleted: Bool = true
    internal var isTrash: Bool = false
    internal var isInbox: Bool = false
    internal var isTag: Bool = false
    var red: Double = 0.34
    var green: Double = 0.119
    var blue: Double = 0.230
    var symbol: String = "folder"
    var notes: [Note] { isTag ? tagNotes : folderNotes }

    init(
        canBeDeleted: Bool = true,
        isTrash: Bool = false,
        isInbox: Bool = false,
        name: String = "New Folder",
        symbol: String = "folder",
        isTag: Bool = false
    ) {
        self.name = name
        self.canBeDeleted = canBeDeleted
        self.isTrash = isTrash
        self.isInbox = isInbox
        self.symbol = symbol
        self.isTag = isTag
    }

    func setColor(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func getSystemImageName() -> String {
        if !isTag {
            if isTrash && folderNotes.isEmpty {
                return "trash"
            }
            if isTrash && !folderNotes.isEmpty {
                return "trash.fill"
            }
            if isInbox && folderNotes.isEmpty {
                return "tray"
            }
            if isInbox && !folderNotes.isEmpty {
                return "tray.fill"
            }
            return symbol
        }

        if tagNotes.isEmpty {
            return "tag"
        }
        if !tagNotes.isEmpty {
            return "tag.fill"
        }
        return symbol
    }

}
