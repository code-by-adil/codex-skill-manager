import CodexSkillCore
import Foundation

struct SkillPackage: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var scope: SkillPackageScope
    var skillNames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        scope: SkillPackageScope,
        skillNames: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.skillNames = skillNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SkillPackageScope: Codable, Hashable {
    enum Kind: String, Codable {
        case project
        case global
    }

    var kind: Kind
    var projectID: UUID?
    var provider: SkillProvider?
    var globalLocation: GlobalSkillLocation?

    static func project(_ projectID: UUID, provider: SkillProvider) -> SkillPackageScope {
        SkillPackageScope(kind: .project, projectID: projectID, provider: provider, globalLocation: nil)
    }

    static func global(_ location: GlobalSkillLocation) -> SkillPackageScope {
        SkillPackageScope(kind: .global, projectID: nil, provider: nil, globalLocation: location)
    }

    func matches(project: SkillProject, provider: SkillProvider) -> Bool {
        kind == .project && projectID == project.id && self.provider == provider
    }

    func matches(global location: GlobalSkillLocation) -> Bool {
        kind == .global && globalLocation == location
    }
}
