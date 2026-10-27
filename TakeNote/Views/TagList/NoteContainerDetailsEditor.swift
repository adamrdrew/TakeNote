//
//  NoteContainerColorPicker.swift
//  TakeNote
//
//  Created by Adam Drew on 9/21/25.
//

#if !os(visionOS)
import SFSymbolsPicker
#endif
import SwiftData
import SwiftUI

struct NoteContainerDetailsEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TakeNoteVM.self) private var takeNoteVM

    @State private var newTagColor: Color = .takeNotePink
    @Binding var showColorPopover: Bool
    let noteContainer: NoteContainer
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
                            #if os(visionOS)
                            FolderSymbolPicker(selection: $newSymbol)
                            #else
                            SymbolsPicker(
                                selection: $newSymbol,
                                title: "Pick a symbol",
                                autoDismiss: true
                            )
                            #endif
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
                    do {
                        try modelContext.save()
                        showColorPopover = false
                    } catch {
                        takeNoteVM.presentError(error.localizedDescription)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .labelStyle(.titleAndIcon)
            }
            .padding(.top, 4)
        }
        #if os(macOS) || os(visionOS)
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
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        }
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

#if os(visionOS)
private struct FolderSymbolPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    private struct SymbolChoice: Identifiable {
        let id: String
        let title: LocalizedStringResource
    }

    private let symbols: [SymbolChoice] = [
        .init(id: "folder", title: "Folder"), .init(id: "briefcase", title: "Work"),
        .init(id: "house", title: "Home"), .init(id: "book", title: "Book"),
        .init(id: "graduationcap", title: "Study"), .init(id: "lightbulb", title: "Ideas"),
        .init(id: "star", title: "Star"), .init(id: "heart", title: "Heart"),
        .init(id: "flag", title: "Flag"), .init(id: "bookmark", title: "Bookmark"),
        .init(id: "calendar", title: "Calendar"), .init(id: "checklist", title: "Checklist"),
        .init(id: "pencil", title: "Writing"), .init(id: "doc.text", title: "Document"),
        .init(id: "tray", title: "Tray"), .init(id: "archivebox", title: "Archive"),
        .init(id: "person", title: "Person"), .init(id: "person.2", title: "People"),
        .init(id: "airplane", title: "Travel"), .init(id: "car", title: "Car"),
        .init(id: "leaf", title: "Nature"), .init(id: "fork.knife", title: "Food"),
        .init(id: "gift", title: "Gift"), .init(id: "music.note", title: "Music")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 16) {
                    ForEach(symbols) { symbol in
                        Button {
                            selection = symbol.id
                            dismiss()
                        } label: {
                            Image(systemName: symbol.id)
                                .font(.title)
                                .frame(width: 60, height: 60)
                        }
                        .accessibilityLabel(Text(symbol.title))
                    }
                }
                .padding()
            }
            .navigationTitle("Pick a symbol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .frame(width: 480, height: 420)
    }
}
#endif
