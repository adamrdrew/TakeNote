import SwiftUI

extension ToolbarItemVisibilityPriority {
    static var takeNotePrimary: Self {
        #if os(visionOS)
        .automatic
        #else
        .high
        #endif
    }

    static var takeNoteSecondary: Self {
        #if os(visionOS)
        .automatic
        #else
        .low
        #endif
    }
}
