import Foundation

public struct SkillProject: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String

    public init(id: UUID = UUID(), name: String? = nil, path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let standardizedURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
            .standardizedFileURL

        self.id = id
        self.path = standardizedURL.path
        self.name = name ?? Self.defaultName(for: standardizedURL)
    }

    public var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func defaultName(for url: URL) -> String {
        let lastComponent = url.lastPathComponent
        return lastComponent.isEmpty ? url.path : lastComponent
    }
}
