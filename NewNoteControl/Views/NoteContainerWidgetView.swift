//
//  NoteContainerWidgetView.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//
import SwiftUI
import AppIntents
import WidgetKit

struct NoteContainerWidgetView: View {
    let entry: NoteListEntry
    let showNewButton: Bool

    var body: some View {
        VStack {
            // Title row + actions
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: entry.symbol)
                Text(entry.name)
                    .font(.headline).bold()
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(entry.totalNoteCount)")
                    .font(.headline).bold()
                    .foregroundStyle(.primary)
            }
            //.frame(maxHeight: .infinity, alignment: .top)

            // Note list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.rows.prefix(3)) { row in
                    if let url = URL(string: row.url) {
                        Link(destination: url) {
                            Text(row.title.isEmpty ? "Untitled" : row.title)
                                .font(.callout)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if !entry.isPlaceholder && entry.rows.isEmpty {
                    Text("No notes")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )

            HStack {
                Spacer()
                if showNewButton {
                    // Create a new note via your AppIntent
                    Button(intent: NewNoteIntent()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .imageScale(.medium)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityLabel("New Note")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(for: .widget) {
            // Your custom brand color (exists in your asset catalog)
            ZStack {
                Color(.takeNotePink)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.50)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
