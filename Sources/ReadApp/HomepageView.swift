import ReadCore
import SwiftUI

struct HomepageView: View {
    @ObservedObject var model: ReadAppModel
    @Environment(\.readerTheme) private var theme

    @State private var currentPage = 0
    private let pageSize = 5

    /// Vim-style h/j navigation between cards on the current page — h moves
    /// up, j moves down, both scrolling the selected card into view.
    @State private var selectedStoryID: String?
    @FocusState private var isListFocused: Bool

    private var pageCount: Int {
        max(1, Int(ceil(Double(model.stories.count) / Double(pageSize))))
    }

    private var pagedStories: [Story] {
        let start = currentPage * pageSize
        guard start < model.stories.count else {
            return []
        }
        let end = min(start + pageSize, model.stories.count)
        return Array(model.stories[start..<end])
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("top")

                    if let error = model.lastRefreshError {
                        Text(error)
                            .font(ReaderTheme.sans(13))
                            .foregroundStyle(.red)
                            .padding(.bottom, 16)
                    }

                    if let status = model.refreshStatus {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(status)
                                .font(ReaderTheme.sans(13))
                                .foregroundStyle(theme.inkSecondary)
                        }
                        .padding(.bottom, 16)
                    }

                    if model.sources.isEmpty {
                        emptyState
                    } else if model.stories.isEmpty, !model.isRefreshing {
                        Text("No stories yet — hit refresh to pull the latest from your tracked sources.")
                            .font(ReaderTheme.sans(14))
                            .foregroundStyle(theme.inkSecondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(pagedStories) { story in
                                StoryRow(
                                    story: story,
                                    isEnriching: story.excerpt == nil && model.isRefreshing,
                                    isSelected: story.id == selectedStoryID,
                                    voteState: model.votedStoryIDs[story.id],
                                    select: { model.openStory(story) },
                                    vote: { isUpvote in model.vote(story, isUpvote: isUpvote) }
                                )
                                .id(story.id)
                            }
                        }

                        if model.stories.count > pageSize {
                            paginationControls
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isListFocused)
            .onKeyPress { press in
                handleKeyPress(press, proxy: scrollProxy)
            }
            .onAppear {
                isListFocused = true
            }
            .onChange(of: currentPage) {
                selectedStoryID = nil
                withAnimation {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
            .onChange(of: model.homeRequestID) {
                currentPage = 0
                selectedStoryID = nil
                withAnimation {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .background(theme.texturedPaper)
        .preferredColorScheme(.light)
        .navigationTitle("Read")
        .toolbarBackground(theme.headerTint, for: .windowToolbar)
        .onChange(of: model.isRefreshing) {
            if model.isRefreshing {
                currentPage = 0
                selectedStoryID = nil
            }
        }
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
            ToolbarItem(placement: .automatic) {
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.sources.isEmpty)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    model.isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView(model: model)
        }
        .task {
            if model.stories.isEmpty {
                await model.refresh()
            }
        }
    }

    private func handleKeyPress(_ press: KeyPress, proxy: ScrollViewProxy) -> KeyPress.Result {
        guard !pagedStories.isEmpty else {
            return .ignored
        }
        switch press.characters {
        case "j":
            moveSelection(by: 1, proxy: proxy)
            return .handled
        case "h":
            moveSelection(by: -1, proxy: proxy)
            return .handled
        default:
            return .ignored
        }
    }

    private func moveSelection(by delta: Int, proxy: ScrollViewProxy) {
        let ids = pagedStories.map(\.id)
        guard !ids.isEmpty else {
            return
        }
        let currentIndex = selectedStoryID.flatMap { ids.firstIndex(of: $0) } ?? -1
        let newIndex = min(max(currentIndex + delta, 0), ids.count - 1)
        selectedStoryID = ids[newIndex]
        withAnimation {
            proxy.scrollTo(ids[newIndex], anchor: .center)
        }
    }

    private var paginationControls: some View {
        HStack {
            PaginationButton(title: "Previous", systemImage: "chevron.left", iconLeading: true, isDisabled: currentPage == 0) {
                currentPage -= 1
            }

            Spacer()

            Text("Page \(currentPage + 1) of \(pageCount)")
                .font(ReaderTheme.sans(12, weight: .medium))
                .foregroundStyle(theme.inkSecondary)

            Spacer()

            PaginationButton(title: "Next", systemImage: "chevron.right", iconLeading: false, isDisabled: currentPage >= pageCount - 1) {
                currentPage += 1
            }
        }
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing tracked yet")
                .font(ReaderTheme.serif(20, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text("Add a few sites in Settings and Read will pull headlines from each one onto this page.")
                .font(ReaderTheme.sans(14))
                .foregroundStyle(theme.inkSecondary)
            Button("Open Settings") {
                model.isShowingSettings = true
            }
            .padding(.top, 4)
        }
        .padding(.top, 40)
    }
}

/// One entry in the news "river" — a timestamp and a node on a connecting
/// rail down the left edge, the story itself, and up/down vote buttons on
/// the right that train the ranker on what you like.
private struct StoryRow: View {
    let story: Story
    let isEnriching: Bool
    let isSelected: Bool
    let voteState: Bool?
    let select: () -> Void
    let vote: (Bool) -> Void

    @Environment(\.readerTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(Self.relativeTime(story.fetchedAt))
                .font(ReaderTheme.sans(10, weight: .medium))
                .foregroundStyle(theme.inkSecondary)
                .frame(width: 54, alignment: .trailing)
                .padding(.top, 20)

            TimelineRail(voteState: voteState, vote: vote)
                .frame(width: 26)

            Button(action: select) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(story.sourceName.uppercased())
                        .font(ReaderTheme.sans(11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(theme.inkSecondary)

                    Text(story.title)
                        .font(ReaderTheme.serif(19, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    if let excerpt = story.excerpt, !excerpt.isEmpty {
                        Text(excerpt)
                            .font(ReaderTheme.serif(14))
                            .foregroundStyle(theme.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(12)
                            .lineSpacing(3)
                    } else if isEnriching {
                        HStack(spacing: 8) {
                            RefinedLoader()
                            Text("Loading…")
                                .font(ReaderTheme.sans(11, weight: .medium))
                                .foregroundStyle(theme.inkSecondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .background(isSelected ? theme.paperInset : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private static func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        switch seconds {
        case ..<60:
            return "now"
        case ..<3600:
            return "\(seconds / 60)m"
        case ..<86400:
            return "\(seconds / 3600)h"
        default:
            return "\(seconds / 86400)d"
        }
    }
}

/// Each row draws its own line segment spanning its own full height; since
/// rows stack with no spacing between them, the segments join into one
/// continuous rail down the whole list without any cross-row coordination.
/// The up/down vote buttons live directly on the rail, in place of a plain
/// node dot, so voting reads as part of the same "stream" rather than a
/// separate control bolted onto the side.
private struct TimelineRail: View {
    let voteState: Bool?
    let vote: (Bool) -> Void

    @Environment(\.readerTheme) private var theme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(theme.rule)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(spacing: 3) {
                VoteIconButton(systemName: "chevron.up.circle", isActive: voteState == true) {
                    vote(true)
                }
                VoteIconButton(systemName: "chevron.down.circle", isActive: voteState == false) {
                    vote(false)
                }
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct PaginationButton: View {
    let title: String
    let systemImage: String
    let iconLeading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.readerTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if iconLeading {
                    Image(systemName: systemImage)
                }
                Text(title)
                if !iconLeading {
                    Image(systemName: systemImage)
                }
            }
            .font(ReaderTheme.sans(12, weight: .medium))
            .foregroundStyle(isDisabled ? theme.rule : (isHovering ? theme.inkSecondary : theme.ink))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovering && !isDisabled ? theme.paperInset : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in isHovering = hovering }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }
}

/// A calm, minimal loading indicator — three small dots pulsing in
/// sequence — in place of the earlier blocky pixel-grid animation.
private struct RefinedLoader: View {
    @State private var activeIndex = 0
    @Environment(\.readerTheme) private var theme

    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(theme.inkSecondary)
                    .frame(width: 4, height: 4)
                    .opacity(index == activeIndex ? 0.9 : 0.25)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}
