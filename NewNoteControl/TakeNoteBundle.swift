//
//  TakeNoteBundle.swift
//  TakeNoteBundle
//
//  Created by Adam Drew on 9/20/25.
//

import WidgetKit
import SwiftUI

@main
struct TakeNoteBundle: WidgetBundle {
    var body: some Widget {
        NewNoteControl()
        InboxWidget()
        StarredWidget()
    }
}
