//
//  ChatFeatureFlagEnabled.swift
//  TakeNote
//
//  Created by Adam Drew on 9/6/25.
//
import SwiftUI

var chatFeatureFlagEnabled: Bool {
    return Bundle.main.object(forInfoDictionaryKey: "MagicChatEnabled") as? Bool
        ?? false
}
