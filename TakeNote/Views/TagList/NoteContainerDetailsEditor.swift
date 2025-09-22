//
//  NoteContainerColorPicker.swift
//  TakeNote
//
//  Created by Adam Drew on 9/21/25.
//

import SFSymbolsPicker
import SwiftUI

struct NoteContainerDetailsEditor: View {
    @Environment(\.modelContext) private var modelContext

    @State var newTagColor: Color = .takeNotePink
    @Binding var showColorPopover: Bool
    @State var noteContainer: NoteContainer
    @State var newSymbol: String = "folder"
    @State var newName: String = ""
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Name").font(.headline)
            TextField("Name", text: $newName)
            Text("Symbol").font(.headline)
            Image(systemName: newSymbol).font(.title3)
            Button("Select a symbol") {
                isPresented.toggle()
            }

            .sheet(
                isPresented: $isPresented,
                content: {
                    SymbolsPicker(
                        selection: $newSymbol,
                        title: "Pick a symbol",
                        autoDismiss: true
                    )
                }
            ).padding()

            Text("Color").font(.headline)
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
                    noteContainer.name = newName
                    noteContainer.symbol = newSymbol
                    try? modelContext.save()
                    showColorPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            newSymbol = noteContainer.symbol
            newTagColor = noteContainer.getColor()
            newName = noteContainer.name
        }
        #if os(macOS)
            .frame(width: 240, height: 320)  // nice compact popover
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
