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

            Button("Continue", action: onDone)
                .keyboardShortcut(.defaultAction)
                .foregroundStyle(.takeNotePink)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
