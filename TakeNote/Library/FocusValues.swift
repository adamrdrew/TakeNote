//
//  FocusValues.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

// Add this to a shared utilities file:
import SwiftData
import SwiftUI

struct ModelContextFocusedValueKey: FocusedValueKey {
    typealias Value = ModelContext
}

extension FocusedValues {
    var modelContext: ModelContext? {
        get { self[ModelContextFocusedValueKey.self] }
        set { self[ModelContextFocusedValueKey.self] = newValue }
    }
}
