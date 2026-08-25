import ReadCore
import SwiftUI

struct PermalinkView: View {
    @ObservedObject var model: ReadAppModel
    let story: Story

    @Environment(\.readerTheme) private var theme
    @State private var article: Article?
    @State private var isLoadingArticle = false
    @State private var articleLoadFailed = false

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
                        VoteIconButton(systemName: "chevron.up.circle", isActive: model.votedStoryIDs[story.id] == true) {
                            model.vote(story, isUpvote: true)
                        }
                        VoteIconButton(systemName: "chevron.down.circle", isActive: model.votedStoryIDs[story.id] == false) {
                            model.vote(story, isUpvote: false)
                        }
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
                }
                .buttonStyle(.plain)
                .help("Back to the top of page 1")
            }
        }
        .task {
            await loadArticle()
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
