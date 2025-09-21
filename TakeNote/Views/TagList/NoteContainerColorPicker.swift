//
//  NoteContainerColorPicker.swift
//  TakeNote
//
//  Created by Adam Drew on 9/21/25.
//

import SwiftUI

struct NoteContainerColorPicker: View {
    @Environment(\.modelContext) private var modelContext

    @State var newTagColor: Color = .takeNotePink
    @Binding var showColorPopover: Bool
    @State var noteContainer: NoteContainer

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Tag Color").font(.headline)
            ColorPicker(
                "Color",
                selection: $newTagColor,
                supportsOpacity: false
            )
            .labelsHidden()
            HStack {
                Button("Cancel") { showColorPopover = false }
                Button("Save") {
                    noteContainer.setColor(newTagColor)
                    try? modelContext.save()
                    showColorPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        #if os(macOS)
            .frame(width: 140, height: 160)  // nice compact popover
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .presentationDetents([.medium, .large])  // optional, feels native
            .presentationDragIndicator(.visible)  // optional
        #endif
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
        #if os(macOS)
            .controlSize(.large)
        #endif
    }
}
