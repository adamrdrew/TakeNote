import SwiftUI

struct WelcomeView: View {
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("What's New in TakeNote")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                WelcomeFeatures()
            }
            .frame(maxWidth: 480)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            WelcomeContinueButton(onDone: onDone)
        }
        .frame(idealWidth: 440, idealHeight: 600)
    }
}

private struct WelcomeFeatures: View {
    var body: some View {
        VStack(spacing: 24) {
            WelcomeRow(
                title: "Magic Chat",
                text: "Chat with your notes! Ask questions and get answers right from your notes.",
                systemImage: "message"
            )
            WelcomeRow(
                title: "All Notes Folder",
                text: "The new All Notes folder in the side bar shows all of your notes in one list.",
                systemImage: "text.pad.header"
            )
            WelcomeRow(
                title: "Semantic Search",
                text: "Search all of your notes with natural language.",
                systemImage: "magnifyingglass"
            )
            WelcomeRow(
                title: "Images in Notes",
                text:
                    "Drag and Drop or Import images and add them to your notes.",
                systemImage: "photo"
            )
            WelcomeRow(
                title: "Archived Notes",
                text:
                    "Add notes to Archived to hide them from search and Magic Chat.",
                systemImage: "archivebox"
            )
        }
    }
}

private struct WelcomeContinueButton: View {
    let onDone: () -> Void

    var body: some View {
        Button("Continue", action: onDone)
            .keyboardShortcut(.defaultAction)
            .foregroundStyle(.takeNotePink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(.bar)
    }
}
