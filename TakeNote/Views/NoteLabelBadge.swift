//
//  NoteLabelBadge.swift
//  TakeNote
//
//  Created by Adam Drew on 8/11/25.
//

import SwiftUI
import SwiftData

struct NoteLabelBadge: View {
    var noteLabel : NoteContainer
    
    var body : some View {
        ZStack {
            Circle()
                .fill(
                    Color(
                        red: noteLabel.red,
                        green: noteLabel.green,
                        blue: noteLabel.blue
                    )
                )
                .glassEffect()
                .overlay(
                    Circle().stroke(.separator, lineWidth: 0.5)
                )
            

        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)

    }
        
}
