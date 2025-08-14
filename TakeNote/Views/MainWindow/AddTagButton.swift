//
//  AddTagButton.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import SwiftUI

struct AddTagButton: View {
    
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "tag")
                    .scaleEffect(x: -1, y: 1)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 7))
                    .offset(x: 2, y: -10)
            }
        }
    }
}
