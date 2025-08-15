//
//  MultiNoteViewer.swift
//  TakeNote
//
//  Created by Adam Drew on 8/15/25.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct MultiNoteViewer: View {
    @Binding var notes: Set<Note>

    // Sort to keep a stable Z-order (topmost last)
    private var notesArray: [Note] {
        Array(notes).sorted { ($0.createdDate) < ($1.createdDate) }
    }

    // Classic US Letter aspect: 8.5 × 11
    private let paperAspect: CGFloat = 8.5 / 11.0

    @State private var animGate = false  // drives the fan-in/out

    var body: some View {
        GeometryReader { geo in
            ZStack {


                // Cards
                ZStack {
                    ForEach(Array(notesArray.enumerated()), id: \.element.id) {
                        idx,
                        note in
                        PaperCard(note: note)
                            .frame(
                                width: paperWidth(in: geo.size),
                                height: paperHeight(in: geo.size)
                            )
                            .rotationEffect(.degrees(jitterAngle(note)))
                            .offset(
                                x: jitterX(note),
                                y: jitterY(note) + CGFloat(idx) * 4
                            )  // tiny cascade
                            .zIndex(Double(idx))

                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Sizing helpers

    private func paperWidth(in size: CGSize) -> CGFloat {
        // Fit inside the right pane nicely with margins
        // Keep some horizontal margin even when wide
        let maxW = min(size.width - 120, 680)
        let maxH = size.height - 120
        // Respect aspect ratio
        let widthByHeight = maxH * paperAspect
        return min(maxW, widthByHeight)
    }

    private func paperHeight(in size: CGSize) -> CGFloat {
        paperWidth(in: size) / paperAspect
    }

    // MARK: - “Messy pile” jitter (deterministic per note)

    private func jitterAngle(_ note: Note) -> Double {
        // ~[-7°, +7°]
        let r = stableRand(note, salt: "angle")
        return Double(r * 14.0 - 7.0)
    }

    private func jitterX(_ note: Note) -> CGFloat {
        // ~[-28, +28] pts
        let r = stableRand(note, salt: "x")
        return CGFloat(r * 56.0 - 28.0)
    }

    private func jitterY(_ note: Note) -> CGFloat {
        // ~[-16, +16] pts
        let r = stableRand(note, salt: "y")
        return CGFloat(r * 32.0 - 16.0)
    }

    private func stableRand(_ note: Note, salt: String) -> CGFloat {
        let s = "\(note.id)#\(salt)"
        var h: UInt64 = 1_469_598_103_934_665_603  // FNV-1a 64 offset
        for b in s.utf8 {
            h ^= UInt64(b)
            h &*= 1_099_511_628_211
        }
        // Map to [0,1)
        return CGFloat((h % 10_000)) / 10_000.0
    }
}

// MARK: - Paper card

private struct PaperCard: View {
    let note: Note

    var body: some View {
        ZStack {
            // Paper
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.white, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 6)

            // Content (black text, generous margins)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Title if you have one; fall back to first line
                    if !note.title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty {
                        Text(note.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.bottom, 2)
                    }

                    // Body (Markdown or plain text)
                    if !note.content.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty {
                        Markdown(note.content)
                            .textSelection(.enabled)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("—")
                            .foregroundStyle(.black.opacity(0.3))
                    }
                }
                .padding(48)  // comfy margins for “paper”
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(note.title.isEmpty ? "Note" : note.title)
    }
}
