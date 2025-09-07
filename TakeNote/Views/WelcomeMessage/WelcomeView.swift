import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to TakeNote!")
                .font(.largeTitle)
                .bold()

            // Rows are centered as a block using Spacer() elements inside WelcomeRow; text remains left aligned
            WelcomeRow(
                title: "Rich Links",
                text: "Create links between notes and see note backlinks.",
                systemImage: "link"
            )
            WelcomeRow(
                title: "Magic Format",
                text: "Turn messy plaintext into clean Markdown instantly with AI.",
                systemImage: "wand.and.stars"
            )
            WelcomeRow(
                title: "Magic Assistant",
                text: "AI Helps you write and format rich markdown.",
                systemImage: "brain"
            )
            WelcomeRow(
                title: "Private by Design",
                text:
                    "AI features run directly on your device.",
                systemImage: "lock.shield"
            )

            Button("Continue", action: onDone)
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(.takeNotePink)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
