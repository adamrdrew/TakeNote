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
    @Environment(\.colorScheme) private var colorScheme

    private var rowStyle: NoteContainerWidgetRows.Style {
        switch family {
        case .systemMedium:
            return .medium
        case .systemLarge:
            return .large
        default:
            return .small
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: entry.symbol)
                    Text(entry.name)
                        .font(.subheadline).bold()
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(entry.totalNoteCount, format: .number)
                        .font(.subheadline).bold()
                        .foregroundStyle(.primary)
                }

                NoteContainerWidgetRows(
                    rows: entry.rows,
                    isPlaceholder: entry.isPlaceholder,
                    style: rowStyle
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)

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
}

private struct NoteContainerWidgetRows: View {
    private struct LinkedRow: Identifiable {
        let row: NoteRow
        let destination: URL

        var id: UUID { row.id }
    }

    enum Style {
        case small
        case medium
        case large

        var limit: Int {
            switch self {
            case .small: 4
            case .medium: 3
            case .large: 5
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: 4
            case .medium: 6
            case .large: 8
            }
        }

        var titleFont: Font {
            switch self {
            case .small, .medium: .footnote
            case .large: .callout
            }
        }

        var excerptFont: Font {
            switch self {
            case .small: .caption2
            case .medium: .caption2
            case .large: .footnote
            }
        }

        var showsExcerpt: Bool {
            self != .small
        }
    }

    let rows: [NoteRow]
    let isPlaceholder: Bool
    let style: Style

    private var linkedRows: [LinkedRow] {
        rows
            .prefix(style.limit)
            .compactMap { row in
                guard let destination = URL(string: row.url) else { return nil }
                return LinkedRow(row: row, destination: destination)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            ForEach(linkedRows) { linkedRow in
                Link(destination: linkedRow.destination) {
                    VStack(alignment: .leading, spacing: 2) {
                        if linkedRow.row.title.isEmpty {
                            Text("Untitled")
                                .font(style.titleFont)
                                .bold(style.showsExcerpt)
                                .lineLimit(1)
                        } else {
                            Text(linkedRow.row.title)
                                .font(style.titleFont)
                                .bold(style.showsExcerpt)
                                .lineLimit(1)
                        }
                        if style.showsExcerpt {
                            Text(linkedRow.row.excerpt)
                                .font(style.excerptFont)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !isPlaceholder && rows.isEmpty {
                Text("No notes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
