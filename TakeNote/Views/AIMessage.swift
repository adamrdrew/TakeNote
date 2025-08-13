//
//  AIMessage.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI

struct AIMessage: View {

    var message: String
    var font: Font

    var body: some View {
        Label {
            Text(message)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "apple.intelligence")
                .symbolRenderingMode(.hierarchical)

        }
        .symbolEffect(.bounce.down)
        .symbolEffect(.rotate)
        .foregroundStyle(
            .linearGradient(
                colors: [.orange, .pink, .blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            ),

        )
        Spacer()

    }
}
