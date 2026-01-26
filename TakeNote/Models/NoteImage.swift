//
//  NoteImage.swift
//  TakeNote
//
//  Created by Adam Drew on 9/9/25.
//

import Foundation
import SwiftData
import SwiftUI

// Hey!
// Hey you!
// If you change model schema remember to bump ckBootstrapVersionCurrent
// in TakeNoteApp.swift
//
// And don't forget to promote to prod!!!

@Model
class NoteImage {
    private(set) var uuid: UUID = UUID()
    @Attribute(.externalStorage) var data: Data
    var mimeType: String
    var referenceCount: Int
    var createdDate: Date = Date()
    @Relationship var noteLinks: [NoteImageLink]? = []

    init(data: Data, mimeType: String, referenceCount: Int = 0) {
        self.data = data
        self.mimeType = mimeType
        self.referenceCount = referenceCount
        self.uuid = UUID()
    }

    func getURL() -> String {
        return "takenote://image/\(uuid.uuidString)"
    }
}
