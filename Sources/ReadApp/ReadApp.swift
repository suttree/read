import SwiftUI

@main
struct ReadApp: App {
    @StateObject private var model = ReadAppModel()

    init() {
        AppIconTheming.applyStoredSelection()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 560)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Menu("Theme") {
                    ForEach(ReaderTheme.allCases) { theme in
                        Button(theme.title) {
                            model.theme = theme
                        }
                    }
                }
            }
            CommandGroup(after: .sidebar) {
                Button("Back") {
                    model.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    model.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: ReadAppModel

    var body: some View {
        Group {
            if model.isUnlocked, !model.isLockedByInactivity {
                NavigationStack(path: $model.path) {
                    HomepageView(model: model)
                        .navigationDestination(for: ReadRoute.self) { route in
                            switch route {
                            case .story(let id):
                                if let story = model.story(withID: id) {
                                    PermalinkView(model: model, story: story)
                                }
                            }
                        }
                }
            } else {
                UnlockView(
                    isCreatingPassword: !model.hasStoredPassword,
                    isUnlocking: model.isUnlocking,
                    errorMessage: model.passwordErrorMessage,
                    unlock: model.isLockedByInactivity ? model.unlockFromInactivityLock : model.unlock
                )
            }
        }
        .environment(\.readerTheme, model.theme)
    }
}
