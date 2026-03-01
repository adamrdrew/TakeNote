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

    @State private var newTagColor: Color = .takeNotePink
    @Binding var showColorPopover: Bool
    @State var noteContainer: NoteContainer
    @State private var newSymbol: String = "folder"
    @State private var newName: String = ""
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 16) {
            // Header — mirrors NoteSortPopover style
            HStack(alignment: .firstTextBaseline) {
                Label("Edit Details", systemImage: "folder.badge.gearshape")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            // Name
            LabeledContainer(
                title: "Name",
                subtitle: "Shown in the sidebar and headers."
            ) {
                TextField("Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Name")
            }

            if !noteContainer.isTag {
                // Symbol
                LabeledContainer(
                    title: "Symbol",
                    subtitle: "Pick a symbol to represent this."
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: newSymbol)
                            .font(.title3)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        
                        Button("Select a symbol") {
                            isPresented.toggle()
                        }
                        .buttonStyle(.bordered)
                        .sheet(isPresented: $isPresented) {
                            SymbolsPicker(
                                selection: $newSymbol,
                                title: "Pick a symbol",
                                autoDismiss: true
                            )
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Select symbol")
                }
            }

            // Color
            LabeledContainer(
                title: "Color",
                subtitle: "Used for accents and identification."
            ) {
                HStack(spacing: 12) {

                    ColorPicker(
                        "Color",
                        selection: $newTagColor,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    Spacer()
                }
                .padding(.vertical, 2)
            }

            // Footer actions
            HStack(spacing: 12) {
                Button("Cancel") { showColorPopover = false }
                    .buttonStyle(.borderless)

                Spacer()

                Button("Save") {
                    noteContainer.setColor(newTagColor)
                    noteContainer.name = newName
                    noteContainer.symbol = newSymbol
                    try? modelContext.save()
                    showColorPopover = false
                }
                .keyboardShortcut(.defaultAction)
                .labelStyle(.titleAndIcon)
            }
            .padding(.top, 4)
        }
        #if os(macOS)
            .frame(width: 280, height: 420)  // align with NoteSortPopover sizing
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .onAppear {
            newSymbol = noteContainer.symbol
            newTagColor = noteContainer.getColor()
            newName = noteContainer.name
        }
    }
}

// MARK: - Decorative container (mirrors the one used in NoteSortPopover)
private struct LabeledContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !subtitle.isEmpty {
                    Text(LocalizedStringKey(subtitle))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator.opacity(0.25))
        )
    }
}
