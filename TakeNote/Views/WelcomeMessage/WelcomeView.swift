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
                title: "Widgets",
                text: "Add widgets to your home screen to keep your notes handy.",
                systemImage: "widget.small"
            )
            WelcomeRow(
                title: "Control Center",
                text: "Create a new note from the Control Center",
                systemImage: "switch.2"
            )
            WelcomeRow(
                title: "Shortcuts Integration",
                text: "Create notes from Shortcuts",
                systemImage: "gear"
            )
            WelcomeRow(
                title: "iPad Support",
                text:
                    "Use TakeNote on your iPad!",
                systemImage: "ipad"
            )

            Button("Continue", action: onDone)
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(.takeNotePink)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
