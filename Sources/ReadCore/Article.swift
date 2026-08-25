import Foundation

/// The full extracted content of one story, fetched on demand when its
/// permalink page is opened (not pre-fetched for every headline on the
/// homepage, to keep refreshes fast).
public struct Article: Codable, Equatable, Sendable {
    public let title: String
    public let bodyText: String
    public let imageURL: String?
    public let sourceURL: String

    public init(title: String, bodyText: String, imageURL: String?, sourceURL: String) {
        self.title = title
        self.bodyText = bodyText
        self.imageURL = imageURL
        self.sourceURL = sourceURL
    }
}
