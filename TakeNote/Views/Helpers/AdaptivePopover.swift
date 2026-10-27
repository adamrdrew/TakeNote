//
//  AdaptivePopover.swift
//  TakeNote
//
//  Created by Adam Drew on 3/1/26.
//

import SwiftUI

/// Keeps one presentation identity while the system adapts between a popover
/// and a compact sheet, including when moving between Duo's displays.
struct AdaptivePopover<PopoverContent: View>: ViewModifier {
    @Binding private var isPresented: Bool
    private let attachmentAnchor: PopoverAttachmentAnchor
    private let arrowEdge: Edge
    @ViewBuilder private let popoverContent: () -> PopoverContent

    init(
        isPresented: Binding<Bool>,
        attachmentAnchor: PopoverAttachmentAnchor,
        arrowEdge: Edge,
        @ViewBuilder popoverContent: @escaping () -> PopoverContent
    ) {
        self._isPresented = isPresented
        self.attachmentAnchor = attachmentAnchor
        self.arrowEdge = arrowEdge
        self.popoverContent = popoverContent
    }

    func body(content: Content) -> some View {
        content.popover(
            isPresented: $isPresented,
            attachmentAnchor: attachmentAnchor,
            arrowEdge: arrowEdge
        ) {
            popoverContent()
            #if os(iOS)
            .presentationCompactAdaptation(.sheet)
            #endif
        }
    }
}

extension View {
    func adaptivePopover<Content: View>(
        isPresented: Binding<Bool>,
        attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(AdaptivePopover(
            isPresented: isPresented,
            attachmentAnchor: attachmentAnchor,
            arrowEdge: arrowEdge,
            popoverContent: content
        ))
    }
}
