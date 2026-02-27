// Hey! // Hey you!
// If you change any persisted fields in this model you need to:
// 1. Bump ckBootstrapVersionCurrent in TakeNoteApp.swift
// 2. Run a DEBUG build to push the schema to the CloudKit dev environment
// 3. Promote the schema from dev to production via the CloudKit Dashboard
// And don't forget to promote to prod!!!

import Foundation
import SwiftData

@Model
final class NoteImage {

    /// Stable identifier for this image across devices.
    /// private(set): only assigned at creation; SwiftData internal hydration is the only
    /// permitted setter invocation after that.
    private(set) var imageUUID: UUID = UUID()

    /// Raw binary image data (JPEG or PNG).
    var imageData: Data = Data()

    /// MIME type of the stored data. Either "image/jpeg" or "image/png".
    var mimeType: String = "image/jpeg"

    /// Creation timestamp.
    var createdDate: Date = Date()

    /// Designated initializer. Generates a fresh UUID for imageUUID.
    init(imageData: Data, mimeType: String) {
        self.imageUUID = UUID()
        self.imageData = imageData
        self.mimeType = mimeType
        self.createdDate = Date()
    }
}
