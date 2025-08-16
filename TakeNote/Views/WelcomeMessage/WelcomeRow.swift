//
//  WelcomeRow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftUI

struct WelcomeRow: View {
    var title: String
    var text: String
    var systemImage: String
    var textWidth: CGFloat = 175  // tweak as needed

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.takeNotePink)
                .padding(.top, 2)  // optical align with headline
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: textWidth, alignment: .leading)  // fixed width -> wrap
            .fixedSize(horizontal: false, vertical: true)  // allow multi-line
            .layoutPriority(1)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
