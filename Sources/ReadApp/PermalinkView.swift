import ReadCore
import SwiftUI

struct PermalinkView: View {
    @ObservedObject var model: ReadAppModel
    let story: Story

    @Environment(\.readerTheme) private var theme
    @State private var article: Article?
    @State private var isLoadingArticle = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(story.sourceName.uppercased())
                    .font(ReaderTheme.sans(11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.inkSecondary)

                Text(article?.title ?? story.title)
                    .font(ReaderTheme.serif(30, weight: .bold))
                    .foregroundStyle(theme.ink)

                if isLoadingArticle {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Fetching article…")
                            .font(ReaderTheme.sans(13))
                            .foregroundStyle(theme.inkSecondary)
                    }
                    .padding(.top, 12)
                } else {
                    // The vote buttons sit outside the "did the text load"
                    // branch on purpose: a story whose page never loaded is
                    // often exactly the kind you want to downvote — site
                    // chrome, a paywall, a link roundup — and that signal is
                    // lost if the only way to give it is on stories that
                    // worked.
                    HStack(spacing: 10) {
                        Rectangle().fill(theme.rule).frame(height: 1)
                        RatingButton(isLit: model.isRated(story)) {
                            model.toggleRating(story)
                        }
                        .layoutPriority(1)
                        Rectangle().fill(theme.rule).frame(height: 1)
                    }

                    if let article {
                        Text(article.bodyText)
                            .font(ReaderTheme.serif(16))
                            .foregroundStyle(theme.ink)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    } else {
                        Text("Couldn't load the full text for this story.")
                            .font(ReaderTheme.sans(13))
                            .foregroundStyle(theme.inkSecondary)
                    }
                }

                if let url = URL(string: story.storyURL) {
                    Link(destination: url) {
                        Label("Read Original", systemImage: "arrow.up.right.square")
                    }
                    .font(ReaderTheme.sans(13, weight: .medium))
                    .padding(.top, 12)
                }
            }
            .padding(28)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(theme.texturedPaper)
        .preferredColorScheme(.light)
        // Left empty rather than set to the story title: the header shows
        // its own composed title (wordmark + middot + article title) via
        // PermalinkBrandToolbarItem below, and a non-empty navigationTitle
        // here would have macOS draw its own plain-text title right next to
        // that — the two running together with no separator at all was
        // exactly the problem.
        .navigationTitle("")
        .toolbarBackground(theme.headerPaint, for: .windowToolbar)
        .toolbar {
            PermalinkBrandToolbarItem(title: article?.title ?? story.title) {
                model.goHome()
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in
            handleKeyPress(press)
        }
        .onAppear {
            isFocused = true
            // Opening a story is what takes it off the Feed queue — the
            // permalink is the one place in the app that's unambiguously "you
            // read this."
            model.markRead(story)
        }
        .task {
            await loadArticle()
        }
    }

    /// j/k step to the next/previous story without returning to the list, x
    /// flips the bolt — the same key that rates the selected card on the feed,
    /// so rating is one key wherever you are — r toggles read/unread (opening
    /// the story already marked it read; this is for undoing that), and Esc or
    /// Backspace jumps straight back to the feed. A story's own page acts as a mini reading session rather than
    /// a one-off page you always have to go back to the list from.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters {
        case "j":
            model.showAdjacentStory(from: story, offset: 1)
            return .handled
        case "k":
            model.showAdjacentStory(from: story, offset: -1)
            return .handled
        case "x":
            model.toggleRating(story)
            return .handled
        case "r":
            model.toggleRead(story)
            return .handled
        default:
            // Backspace reports as `.delete` (forward delete is
            // `.deleteForward`), but some keyboard layouts deliver it as the
            // raw control character with no key name attached, so both spellings
            // are accepted rather than trusting one.
            if press.key == .delete || press.key == .escape
                || press.characters == "\u{8}" || press.characters == "\u{7F}" {
                model.goBack()
                return .handled
            }
            return .ignored
        }
    }

    private func loadArticle() async {
        if let cached = model.article(for: story) {
            article = cached
            return
        }
        isLoadingArticle = true
        article = await model.loadArticle(for: story)
        isLoadingArticle = false
    }
}
