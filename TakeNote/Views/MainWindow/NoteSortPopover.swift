//
//  NoteSortPopover.swift
//  TakeNote
//
//  Created by Adam Drew on 9/21/25.
//

import SwiftUI

/// A compact, polished control surface for choosing the note list sort options.
/// Drop this into a `.popover` anywhere you want.
struct NoteSortPopover: View {
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        VStack(spacing: 16) {
            header

            // Sort By
            LabeledContainer(
                title: "Sort by",
                subtitle: "Choose which timestamp drives ordering."
            ) {
                Picker("Sort by", selection: $takeNoteVM.sortBy) {
                    Label("Created", systemImage: "calendar.badge.plus").tag(
                        SortBy.created
                    )
                    Label("Updated", systemImage: "arrow.clockwise").tag(
                        SortBy.updated
                    )
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Sort by")
            }

            // Sort Order
            LabeledContainer(
                title: "Order",
                subtitle: "Pick direction of the list."
            ) {
                Picker("Order", selection: $takeNoteVM.sortOrder) {
                    Label("Newest first", systemImage: "arrow.down.to.line")
                        .tag(SortOrder.newestFirst)
                    Label("Oldest first", systemImage: "arrow.up.to.line").tag(
                        SortOrder.oldestFirst
                    )
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Sort order")
            }

            // Footer actions
            HStack(spacing: 12) {
                Button(role: .none) {
                    takeNoteVM.sortBy = .created
                    takeNoteVM.sortOrder = .newestFirst
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Restore defaults: Created · Newest first")

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        #if os(macOS)
            .frame(width: 280, height: 320)  // nice compact popover
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Sort Options", systemImage: "arrow.up.arrow.down.circle")
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }
}

// MARK: - Decorative container used above
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
