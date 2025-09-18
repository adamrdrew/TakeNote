//
//  NoteContainer.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//
import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif


// Hey!
// Hey you!
// If you change model schema remember to bump ckBootstrapVersionCurrent
// in TakeNoteApp.swift
//
// And don't forget to promote to prod!!!

@Model
class NoteContainer: Identifiable {
    var name: String = ""
    var folderNotes: [Note]? = []
    var tagNotes: [Note]? = []
    internal var canBeDeleted: Bool = true
    internal var isTrash: Bool = false
    internal var isInbox: Bool = false
    internal var isStarred: Bool = false
    internal var isTag: Bool = false
    internal var isBuffer: Bool = false
    var colorRGBA: UInt32 = 0xE5E5E5FF
    var symbol: String = "folder"
    var notes: [Note] { isTag ? tagNotes! : folderNotes! }

    init(
        canBeDeleted: Bool = true,
        isTrash: Bool = false,
        isInbox: Bool = false,
        isStarred: Bool = false,
        name: String = "New Folder",
        symbol: String = "folder",
        isTag: Bool = false
    ) {
        self.name = name
        self.canBeDeleted = canBeDeleted
        self.isTrash = isTrash
        self.isInbox = isInbox
        self.isStarred = isStarred
        self.symbol = symbol
        self.isTag = isTag
    }

    func getSystemImageName() -> String {
        if !isTag {
            if isTrash && folderNotes!.isEmpty {
                return "trash"
            }
            if isTrash && !folderNotes!.isEmpty {
                return "trash.fill"
            }
            if isInbox && folderNotes!.isEmpty {
                return "tray"
            }
            if isInbox && !folderNotes!.isEmpty {
                return "tray.fill"
            }
            return symbol
        }

        if tagNotes!.isEmpty {
            return "tag"
        }
        if !tagNotes!.isEmpty {
            return "tag.fill"
        }
        return symbol
    }
    
    func getColor() -> Color {
        let r = Double((colorRGBA >> 24) & 0xFF) / 255.0
        let g = Double((colorRGBA >> 16) & 0xFF) / 255.0
        let b = Double((colorRGBA >>  8) & 0xFF) / 255.0
        let a = Double( colorRGBA        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    func setColor(_ color: Color) {
        #if os(macOS)
        guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return }
        #endif
        #if os(iOS) || os(visionOS)
        let ns = UIColor(color)
        #endif
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = UInt32(clamping: Int(r * 255.0))
        let G = UInt32(clamping: Int(g * 255.0))
        let B = UInt32(clamping: Int(b * 255.0))
        let A = UInt32(clamping: Int(a * 255.0))
        colorRGBA = (R << 24) | (G << 16) | (B << 8) | A
    }

}
