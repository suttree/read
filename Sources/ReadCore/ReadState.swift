import Foundation

/// Which stories have been opened (read) and which have been explicitly
/// saved ("hearted") for later — persisted separately from votes, since
/// read/saved status is about triage, not training signal for the ranker.
public struct ReadState: Codable, Sendable {
    public var readIDs: [String]
    public var savedIDs: [String]

    public init(readIDs: [String] = [], savedIDs: [String] = []) {
        self.readIDs = readIDs
        self.savedIDs = savedIDs
    }
}

public protocol ReadStateStore {
    func loadState() throws -> ReadState
    func saveState(_ state: ReadState) throws
}

public final class FileReadStateStore: ReadStateStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadState() throws -> ReadState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ReadState()
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ReadState.self, from: data)
    }

    public func saveState(_ state: ReadState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
