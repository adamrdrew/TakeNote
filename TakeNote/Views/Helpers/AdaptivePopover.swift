//
//  AdaptivePopover.swift
//  TakeNote
//
//  Created by Adam Drew on 3/1/26.
//

import SwiftUI

/// A ViewModifier that presents content as a `.sheet()` on iPad (centered modal)
/// and as a `.popover()` on iPhone and macOS.
struct AdaptivePopover<PopoverContent: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private var prefersSheetPresentation: Bool {
        #if os(iOS)
            return horizontalSizeClass == .regular
        #else
            return false
        #endif
    }

    func body(content: Content) -> some View {
        if prefersSheetPresentation {
            content.sheet(isPresented: $isPresented) {
                popoverContent()
            }
        } else {
            content.popover(
                isPresented: $isPresented,
                attachmentAnchor: attachmentAnchor,
                arrowEdge: arrowEdge
            ) {
                popoverContent()
            }
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
