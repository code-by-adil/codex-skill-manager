import Foundation

public struct SkillItem: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(projectID.uuidString)|\(provider.rawValue)|\(state.rawValue)|\(name)"
    }

    public let projectID: UUID
    public let projectPath: String
    public let provider: SkillProvider
    public let name: String
    public let state: SkillState
    public let url: URL
    public let summary: String?

    public init(
        projectID: UUID,
        projectPath: String,
        provider: SkillProvider,
        name: String,
        state: SkillState,
        url: URL,
        summary: String?
    ) {
        self.projectID = projectID
        self.projectPath = projectPath
        self.provider = provider
        self.name = name
        self.state = state
        self.url = url
        self.summary = summary
    }

    public var isEnabled: Bool {
        state == .active
    }
}
