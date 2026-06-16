import Foundation

enum SkillFilter: String, CaseIterable, Identifiable {
    case all
    case enabled
    case disabled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            "All"
        case .enabled:
            "Enabled"
        case .disabled:
            "Disabled"
        }
    }
}
