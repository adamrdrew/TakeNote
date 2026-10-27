//
//  SidebarContainerIcon.swift
//  TakeNote
//
//  Created by Adam Drew on 6/14/26.
//

import SwiftUI

struct SidebarContainerIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.black.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}
