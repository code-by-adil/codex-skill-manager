import Foundation

public enum GlobalSkillLocation: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex
    case agents

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .codex:
            "Global Codex"
        case .agents:
            "Global Agents"
        }
    }

    public var shortLabel: String {
        switch self {
        case .codex:
            "Codex"
        case .agents:
            "Agents"
        }
    }

    public var configurationDirectoryName: String {
        switch self {
        case .codex:
            ".codex"
        case .agents:
            ".agents"
        }
    }

    public var storageID: UUID {
        switch self {
        case .codex:
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        case .agents:
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        }
    }
}
