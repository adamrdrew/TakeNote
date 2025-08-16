import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to TakeNote!")
                .font(.largeTitle)
                .bold()

            // Center the rows as a block, keep text inside left aligned

            WelcomeRow(
                title: "Magic Format",
                text: "Turn messy plaintext into clean Markdown instantly with AI.",
                systemImage: "wand.and.stars"
            )
            WelcomeRow(
                title: "Magic Chat",
                text: "On device AI chat bot powered by your notes.",
                systemImage: "message"
            )
            WelcomeRow(
                title: "Markdown Assistant",
                text: "AI Helps you write and format rich markdown.",
                systemImage: "brain"
            )
            WelcomeRow(
                title: "Private by Design",
                text:
                    "Your data never leaves your Mac. No servers, no accounts.",
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
