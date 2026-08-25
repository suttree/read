import AppKit
import Foundation
import ReadCore
import SwiftUI

enum ReadRoute: Hashable {
    case story(String)
}

@MainActor
final class ReadAppModel: ObservableObject {
    @Published var sources: [TrackedSource] = []
    @Published var stories: [Story] = []
    @Published var isRefreshing = false
    @Published var refreshStatus: String?
    @Published var lastRefreshError: String?
    @Published var isShowingSettings = false
    @Published var path: [ReadRoute] = []

    @Published var theme: ReaderTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.themeStorageKey)
            AppIconTheming.apply(theme)
        }
    }

    /// Per-card up/down state for whatever's currently on screen — keyed by
    /// story id (which changes every refresh), so this is just UI feedback
    /// for the current batch, not the training history itself (that's
    /// `voteHistory`, keyed on title words instead so it generalizes).
    @Published var votedStoryIDs: [String: Bool] = [:]

    @Published var isUnlocked = false
    @Published var isUnlocking = false
    @Published var hasStoredPassword = false
    @Published var passwordErrorMessage: String?
    @Published var isLockedByInactivity = false
    private static let inactivityLockInterval: TimeInterval = 600
    private var inactivityTimer: Timer?
    private var activityMonitor: Any?

    private let sourceStore: SourceStore
    private let secretStore: PasswordProtectedSecretStore
    private let voteStore: VoteStore
    private let fetcher = ArticleFetcher()
    private var articleCache: [String: Article] = [:]
    private var voteHistory: [VoteRecord] = []
    private var ranker: NaiveBayesRanker

    private static let themeStorageKey = "ReadTheme"

    init() {
        let store = FileSourceStore(fileURL: Self.sourcesFileURL())
        sourceStore = store
        secretStore = PasswordProtectedSecretStore(fileURL: Self.secretFileURL())
        let votes = FileVoteStore(fileURL: Self.votesFileURL())
        voteStore = votes
        sources = (try? store.loadSources()) ?? []
        hasStoredPassword = secretStore.hasStoredPassword
        voteHistory = (try? votes.loadVotes()) ?? []
        ranker = NaiveBayesRanker(votes: voteHistory)
        if let stored = UserDefaults.standard.string(forKey: Self.themeStorageKey), let theme = ReaderTheme(rawValue: stored) {
            self.theme = theme
        } else {
            self.theme = .standard
        }
    }

    private static func sourcesFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Read", isDirectory: true).appendingPathComponent("sources.json")
    }

    private static func votesFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Read", isDirectory: true).appendingPathComponent("votes.json")
    }

    // MARK: - Voting

    /// Records the vote for training, then immediately re-ranks whatever's
    /// currently on screen — voting should feel like it's shaping the feed
    /// right away, not just influencing some future refresh.
    func vote(_ story: Story, isUpvote: Bool) {
        let excerpt = story.excerpt ?? articleCache[story.storyURL]?.bodyText
        voteHistory.append(VoteRecord(title: story.title, sourceName: story.sourceName, contentExcerpt: excerpt, isUpvote: isUpvote))
        try? voteStore.saveVotes(voteHistory)
        votedStoryIDs[story.id] = isUpvote
        ranker = NaiveBayesRanker(votes: voteHistory)
        applyRanking()
    }

    /// Once there's enough signal (a handful of votes in both directions),
    /// reorders the feed by predicted interest instead of raw fetch order —
    /// the "algorithmic stream." Before that, stories stay in whatever order
    /// they were fetched in; a ranker trained on 1-2 votes would just be
    /// reordering things randomly and calling it personalization.
    private func applyRanking() {
        guard ranker.isTrained else {
            return
        }
        stories = stories.sorted { lhs, rhs in
            ranker.score(title: lhs.title, sourceName: lhs.sourceName, excerpt: lhs.excerpt)
                > ranker.score(title: rhs.title, sourceName: rhs.sourceName, excerpt: rhs.excerpt)
        }
    }

    private static func secretFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Read", isDirectory: true).appendingPathComponent("secret.encrypted")
    }

    // MARK: - Lock screen

    func unlock(password: String) {
        guard !isUnlocking, !isUnlocked else {
            return
        }
        isUnlocking = true
        passwordErrorMessage = nil
        do {
            if secretStore.hasStoredPassword {
                try secretStore.unlock(password: password)
            } else {
                try secretStore.createPassword(password)
            }
            isUnlocked = true
            startInactivityMonitoring()
        } catch {
            passwordErrorMessage = error.localizedDescription
        }
        isUnlocking = false
    }

    /// Re-verifies the password after an inactivity auto-lock, without
    /// tearing down or reloading anything else — stories, caches, and the
    /// current page all stay exactly as they were underneath.
    func unlockFromInactivityLock(password: String) {
        guard isLockedByInactivity, !isUnlocking else {
            return
        }
        isUnlocking = true
        passwordErrorMessage = nil
        do {
            try secretStore.unlock(password: password)
            isLockedByInactivity = false
            resetInactivityTimer()
        } catch {
            passwordErrorMessage = error.localizedDescription
        }
        isUnlocking = false
    }

    private func startInactivityMonitoring() {
        guard activityMonitor == nil else {
            return
        }
        resetInactivityTimer()
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.resetInactivityTimer()
            return event
        }
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        guard isUnlocked, !isLockedByInactivity else {
            return
        }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: Self.inactivityLockInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lockDueToInactivity()
            }
        }
    }

    private func lockDueToInactivity() {
        guard isUnlocked, !isLockedByInactivity else {
            return
        }
        secretStore.lock()
        isLockedByInactivity = true
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    /// Belt-and-suspenders against the same story appearing more than once —
    /// e.g. the same site tracked under two slightly different URLs, or two
    /// sources both linking the same wire story.
    private static func deduplicated(_ stories: [Story]) -> [Story] {
        var seenURLs = Set<String>()
        return stories.filter { seenURLs.insert($0.storyURL).inserted }
    }

    // MARK: - Sources

    func addSource(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        let normalized = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://" + trimmed
        guard URL(string: normalized) != nil else {
            return
        }
        sources.append(TrackedSource(url: normalized))
        persistSources()
    }

    func removeSource(_ id: UUID) {
        sources.removeAll { $0.id == id }
        stories.removeAll { $0.sourceID == id }
        persistSources()
    }

    private func persistSources() {
        try? sourceStore.saveSources(sources)
    }

    // MARK: - Homepage refresh

    func refresh() async {
        guard !isRefreshing, !sources.isEmpty else {
            return
        }
        isRefreshing = true
        lastRefreshError = nil
        stories = []

        let sourcesSnapshot = sources
        var headlinesBySource: [UUID: [Story]] = [:]
        var completedSourceCount = 0
        refreshStatus = "Loading sources… 0 of \(sourcesSnapshot.count)"

        // Sources used to be fetched one at a time — with several tracked
        // sites that meant waiting out each one's full page-load timeout in
        // sequence before anything showed up at all. Fetching a few at once,
        // and updating `stories` after each one lands, means headlines start
        // appearing within seconds instead of after everything finishes.
        let maxConcurrentSources = 3
        await withTaskGroup(of: (UUID, [Story]).self) { group in
            var iterator = sourcesSnapshot.makeIterator()
            func addNext() {
                guard let source = iterator.next() else {
                    return
                }
                group.addTask { [fetcher] in
                    (source.id, await fetcher.fetchStories(from: source))
                }
            }
            for _ in 0..<maxConcurrentSources {
                addNext()
            }
            while let (sourceID, sourceStories) = await group.next() {
                headlinesBySource[sourceID] = sourceStories
                completedSourceCount += 1
                refreshStatus = "Loading sources… \(completedSourceCount) of \(sourcesSnapshot.count)"
                stories = Self.deduplicated(headlinesBySource.values.flatMap { $0 }).sorted { $0.fetchedAt > $1.fetchedAt }
                addNext()
            }
        }

        let failureCount = sourcesSnapshot.filter { (headlinesBySource[$0.id] ?? []).isEmpty }.count
        guard failureCount < sourcesSnapshot.count else {
            lastRefreshError = "Couldn't pull any stories from your tracked sources. Check the URLs in Settings."
            refreshStatus = nil
            isRefreshing = false
            return
        }

        await enrichProgressively(stories)
        applyRanking()
        votedStoryIDs = [:]
        refreshStatus = nil
        isRefreshing = false
    }

    /// Visits each story's own page (a few at a time, not all at once) to
    /// fill in a real excerpt, and a hero image for stories whose listing
    /// thumbnail didn't resolve — both far more reliable pulled from the
    /// story's own page than guessed at from listing-page markup. Updates
    /// `stories` in place as each one finishes, so cards fill in
    /// progressively instead of all appearing at once at the very end.
    /// Fetches each story's full text and, when an API key is set, a real
    /// Claude-generated summary to show on its homepage card — replacing the
    /// raw excerpt (opening paragraphs) that's used as a fallback when
    /// there's no key or the summarization call fails. Both happen inside
    /// the same concurrent task per story, not as a separate later pass, so
    /// summarization overlaps with fetching rather than adding its own
    /// serial delay on top.
    /// Fetches each story's full text so its card can show a real excerpt —
    /// no AI summarization here; it's slow (a network round trip per story,
    /// serialized behind a batch) and costs an API call per story on every
    /// refresh. The opening paragraph(s) of the actual article give enough
    /// context on their own.
    private func enrichProgressively(_ storiesToEnrich: [Story]) async {
        let maxConcurrent = 4
        var completed = 0
        var index = 0
        while index < storiesToEnrich.count {
            let batchEnd = min(index + maxConcurrent, storiesToEnrich.count)
            let batch = Array(storiesToEnrich[index..<batchEnd])
            await withTaskGroup(of: (String, Article?).self) { group in
                for story in batch {
                    group.addTask { [fetcher] in
                        guard let url = URL(string: story.storyURL) else {
                            return (story.id, nil)
                        }
                        return (story.id, await fetcher.fetchArticle(url: url))
                    }
                }
                for await (storyID, article) in group {
                    completed += 1
                    refreshStatus = "Fetching story details… \(completed) of \(storiesToEnrich.count)"
                    guard let idx = stories.firstIndex(where: { $0.id == storyID }) else {
                        continue
                    }
                    // Some "headlines" turn out not to be real stories at all
                    // — site-chrome section labels ("Featured Podcasts",
                    // "Upcoming Tech Events") that happened to be marked up
                    // as headings. If the page it links to doesn't actually
                    // have substantial article text, it isn't a story —
                    // drop the card rather than showing an empty one.
                    guard let article, article.bodyText.count >= 120 else {
                        stories.remove(at: idx)
                        continue
                    }
                    articleCache[stories[idx].storyURL] = article
                    if stories[idx].imageURL == nil {
                        stories[idx].imageURL = article.imageURL
                    }
                    stories[idx].excerpt = String(article.bodyText.prefix(1200))
                }
            }
            index = batchEnd
        }
    }

    // MARK: - Permalink

    func article(for story: Story) -> Article? {
        articleCache[story.storyURL]
    }

    func loadArticle(for story: Story) async -> Article? {
        if let cached = articleCache[story.storyURL] {
            return cached
        }
        guard let url = URL(string: story.storyURL) else {
            return nil
        }
        let article = await fetcher.fetchArticle(url: url)
        if let article {
            articleCache[story.storyURL] = article
        }
        return article
    }

    /// Popped routes go here so ⌘] can restore them — standard browser
    /// back/forward semantics: navigating to a new story clears this, so
    /// forward only ever replays what you just went back from.
    private var forwardPath: [ReadRoute] = []

    func openStory(_ story: Story) {
        path.append(.story(story.id))
        forwardPath.removeAll()
    }

    func goBack() {
        guard let last = path.popLast() else {
            return
        }
        forwardPath.append(last)
    }

    func goForward() {
        guard let next = forwardPath.popLast() else {
            return
        }
        path.append(next)
    }

    func story(withID id: String) -> Story? {
        stories.first { $0.id == id }
    }

    /// Bumped whenever "Read" in the toolbar is clicked — HomepageView
    /// listens for this to reset back to page 1 and scroll to the top, the
    /// same way a site logo acts as a home link.
    @Published var homeRequestID = 0

    func goHome() {
        path.removeAll()
        forwardPath.removeAll()
        homeRequestID += 1
    }
}
