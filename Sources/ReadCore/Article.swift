import Foundation

public enum ArticleBlock: Codable, Equatable, Sendable {
    case paragraph(String)
    case image(String)

    private enum CodingKeys: String, CodingKey { case type, value }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let text):
            try container.encode("paragraph", forKey: .type)
            try container.encode(text, forKey: .value)
        case .image(let url):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        switch type {
        case "paragraph": self = .paragraph(value)
        case "image": self = .image(value)
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown article block type")
        }
    }
}

/// The full extracted content of one story, fetched on demand when its
/// permalink page is opened (not pre-fetched for every headline on the
/// homepage, to keep refreshes fast).
public struct Article: Codable, Equatable, Sendable {
    public let title: String
    public let bodyText: String
    public let blocks: [ArticleBlock]
    public let imageURL: String?
    public let sourceURL: String
    /// When the page itself says the story was published — pulled from
    /// `article:published_time`, a `<time datetime>` element, or JSON-LD
    /// `datePublished`, whichever the page actually carries. Nil when none of
    /// those are present, which is common enough that callers need a fallback
    /// rather than treating it as required.
    public let publishedAt: Date?

    public init(title: String, bodyText: String, imageURL: String?, sourceURL: String, publishedAt: Date? = nil, blocks: [ArticleBlock]? = nil) {
        self.title = title
        self.bodyText = bodyText
        self.blocks = blocks ?? bodyText
            .components(separatedBy: "\n\n")
            .filter { !$0.isEmpty }
            .map(ArticleBlock.paragraph)
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey { case title, bodyText, blocks, imageURL, sourceURL, publishedAt }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        bodyText = try container.decode(String.self, forKey: .bodyText)
        blocks = try container.decodeIfPresent([ArticleBlock].self, forKey: .blocks) ?? bodyText
            .components(separatedBy: "\n\n")
            .filter { !$0.isEmpty }
            .map(ArticleBlock.paragraph)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
    }
}
