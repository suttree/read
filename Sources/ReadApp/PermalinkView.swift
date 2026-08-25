import ReadCore
import SwiftUI

struct PermalinkView: View {
    @ObservedObject var model: ReadAppModel
    let story: Story

    @Environment(\.readerTheme) private var theme
    @State private var article: Article?
    @State private var isLoadingArticle = false
    @State private var articleLoadFailed = false
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
                } else if articleLoadFailed {
                    Text("Couldn't load the full text for this story.")
                        .font(ReaderTheme.sans(13))
                        .foregroundStyle(theme.inkSecondary)
                } else if let article {
                    HStack(spacing: 10) {
                        Rectangle().fill(theme.rule).frame(height: 1)
                        HStack(spacing: 10) {
                            VoteIconButton(systemName: "chevron.up.circle", isActive: model.votedStoryIDs[story.id] == true) {
                                model.vote(story, isUpvote: true)
                            }
                            VoteIconButton(systemName: "chevron.down.circle", isActive: model.votedStoryIDs[story.id] == false) {
                                model.vote(story, isUpvote: false)
                            }
                            VoteIconButton(systemName: "heart", isActive: model.savedStoryIDs.contains(story.id)) {
                                model.toggleSaved(story)
                            }
                        }
                        .layoutPriority(1)
                        Rectangle().fill(theme.rule).frame(height: 1)
                    }
                    Text(article.bodyText)
                        .font(ReaderTheme.serif(16))
                        .foregroundStyle(theme.ink)
                        .lineSpacing(6)
                        .textSelection(.enabled)
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
        .navigationTitle(story.title)
        .toolbarBackground(theme.headerTint, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.goHome()
                } label: {
                    Text("Read")
                        .font(ReaderTheme.serif(15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to the top of page 1")
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
            model.markRead(story)
        }
        .task {
            await loadArticle()
        }
    }

    /// j/k step to the next/previous story without returning to the list,
    /// h toggles this story's read/unread status, l toggles saved, and
    /// Backspace jumps straight back to the feed — a story's own page acts
    /// as a mini reading session rather than a one-off page you always have
    /// to go back to the list from.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters {
        case "j":
            model.showAdjacentStory(from: story, offset: 1)
            return .handled
        case "k":
            model.showAdjacentStory(from: story, offset: -1)
            return .handled
        case "h":
            model.toggleRead(story)
            return .handled
        case "l":
            model.toggleSaved(story)
            return .handled
        default:
            if press.key == .delete {
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
        let fetched = await model.loadArticle(for: story)
        isLoadingArticle = false
        if let fetched {
            article = fetched
        } else {
            articleLoadFailed = true
        }
    }
}
