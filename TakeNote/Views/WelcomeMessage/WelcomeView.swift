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
                title: "A Fresh Look for OS 27",
                text: "Updated sidebars, toolbars, and controls across Mac, iPhone, iPad, and Apple Vision Pro.",
                systemImage: "sidebar.left"
            )
            WelcomeRow(
                title: "Built for iPhone Duo",
                text: "Fold and unfold while keeping your note, editing mode, and place in the editor.",
                systemImage: "iphone.duo"
            )
            WelcomeRow(
                title: "Find Notes in Spotlight",
                text: "Search your notes from Spotlight and open a result directly in TakeNote.",
                systemImage: "magnifyingglass.circle.fill"
            )
            WelcomeRow(
                title: "More Siri and Shortcuts Actions",
                text: "Find, edit, and organize notes, folders, and tags with Siri and Shortcuts.",
                systemImage: "arrow.triangle.branch"
            )
            WelcomeRow(
                title: "Updated Magic Chat",
                text: "Ask follow-up questions, see source notes, and ask Magic Chat to save a new note to your Inbox.",
                systemImage: "bubble.left.and.bubble.right"
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
