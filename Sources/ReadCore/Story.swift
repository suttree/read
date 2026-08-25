import Foundation

/// A headline pulled from a tracked source's front page, shown as a card on
/// the homepage. `id` is stable per (source, story URL) pair so a story that
/// reappears across refreshes doesn't get treated as new.
public struct Story: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let storyURL: String
    public let sourceID: UUID
    public let sourceName: String
    public var imageURL: String?
    /// The opening line(s) of the story's own page, filled in by a second
    /// enrichment pass after the headline is found — listing pages mostly
    /// don't carry deck/trail text in the DOM for anything but hero stories.
    public var excerpt: String?
    public let fetchedAt: Date

    public init(
        title: String,
        storyURL: String,
        sourceID: UUID,
        sourceName: String,
        imageURL: String? = nil,
        excerpt: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.id = "\(sourceID.uuidString)|\(storyURL)"
        self.title = title
        self.storyURL = storyURL
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.imageURL = imageURL
        self.excerpt = excerpt
        self.fetchedAt = fetchedAt
    }
}
