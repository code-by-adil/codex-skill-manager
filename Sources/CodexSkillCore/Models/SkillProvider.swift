import Foundation

public enum SkillProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex
    case claude

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .codex:
            "Codex"
        case .claude:
            "Claude"
        }
    }

    public var configurationDirectoryName: String {
        switch self {
        case .codex:
            ".agents"
        case .claude:
            ".claude"
        }
    }
}
