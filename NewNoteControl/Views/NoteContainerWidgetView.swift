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
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // --- Top content: header + list ---
            VStack(alignment: .leading, spacing: 6) {
                // Title row + actions
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: entry.symbol)
                    Text(entry.name)
                        .font(.subheadline).bold()
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(entry.totalNoteCount)")
                        .font(.subheadline).bold()
                        .foregroundStyle(.primary)
                }

                // Content varies by family
                Group {
                    switch family {
                    case .systemMedium:
                        mediumList
                    case .systemLarge:
                        largeList
                    default: // .systemSmall
                        smallList
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0) // pushes button to bottom

            // --- Bottom content: new note button ---
            HStack {
                Spacer()
                if showNewButton {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            if colorScheme == .dark {
                ZStack {
                    Color(.takeNotePink)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                ZStack {
                    Color(.takeNotePink)
                    LinearGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }

    // MARK: - Small (4 titles)
    private var smallList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.rows.prefix(4)) { row in
                if let url = URL(string: row.url) {
                    Link(destination: url) {
                        Text(row.title.isEmpty ? "Untitled" : row.title)
                            .font(.footnote)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if !entry.isPlaceholder && entry.rows.isEmpty {
                Text("No notes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Medium (3 items: smaller title + excerpt)
    private var mediumList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.rows.prefix(3)) { row in
                if let url = URL(string: row.url) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title.isEmpty ? "Untitled" : row.title)
                                .font(.footnote).bold()
                                .lineLimit(1)
                            Text(row.excerpt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if !entry.isPlaceholder && entry.rows.isEmpty {
                Text("No notes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Large (5 items: larger title + excerpt)
    private var largeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.rows.prefix(5)) { row in
                if let url = URL(string: row.url) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title.isEmpty ? "Untitled" : row.title)
                                .font(.callout).bold()
                                .lineLimit(1)
                            Text(row.excerpt)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if !entry.isPlaceholder && entry.rows.isEmpty {
                Text("No notes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
