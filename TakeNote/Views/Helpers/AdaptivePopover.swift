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
    @Binding var isPresented: Bool
    var attachmentAnchor: PopoverAttachmentAnchor
    var arrowEdge: Edge
    @ViewBuilder let popoverContent: () -> PopoverContent

    private var isIPad: Bool {
        #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad
        #else
            return false
        #endif
    }

    func body(content: Content) -> some View {
        if isIPad {
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
