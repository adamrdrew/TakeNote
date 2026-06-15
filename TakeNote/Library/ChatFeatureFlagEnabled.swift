//
//  ChatFeatureFlagEnabled.swift
//  TakeNote
//
//  Created by Adam Drew on 9/6/25.
//
import Foundation

var chatFeatureFlagEnabled: Bool {
    Bundle.main.object(forInfoDictionaryKey: "MagicChatEnabled") as? Bool
        ?? false
}
