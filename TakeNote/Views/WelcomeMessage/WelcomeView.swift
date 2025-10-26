import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("What's New in TakeNote")
                .font(.largeTitle)
                .bold()

            // Rows are centered as a block using Spacer() elements inside WelcomeRow; text remains left aligned
            WelcomeRow(
                title: "Customization",
                text: "Set custom colors for folders and tags, and icons for folders.",
                systemImage: "swatchpalette"
            )
            WelcomeRow(
                title: "Drag to Create",
                text: "Drag any text into the note list to create a new note",
                systemImage: "hand.point.up.left.and.text.fill"
            )
            WelcomeRow(
                title: "Markdown Keyboard Improvements",
                text: "More and better Makrdown keyboard shortcuts",
                systemImage: "number.square"
            )
            WelcomeRow(
                title: "Starred Notes Shortcut",
                text:
                    "Access all starred notes from the sidebar",
                systemImage: "star"
            )

            Button("Continue", action: onDone)
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(.takeNotePink)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
