import Foundation

public enum SkillState: String, Codable, CaseIterable, Sendable {
    case active
    case inactive

    public var label: String {
        switch self {
        case .active:
            "Enabled"
        case .inactive:
            "Disabled"
        }
    }
}
