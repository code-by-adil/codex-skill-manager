import Foundation

public enum SkillTransferMode: String, Sendable {
    case copy
    case move
}

public enum SkillFileServiceError: LocalizedError, Sendable {
    case sourceMissing(URL)
    case destinationExists(URL)
    case invalidSkillDirectory(URL)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing(let url):
            "The skill could not be found at \(url.path)."
        case .destinationExists(let url):
            "A skill already exists at \(url.path)."
        case .invalidSkillDirectory(let url):
            "The selected item is not a skill directory: \(url.path)."
        }
    }
}

public struct SkillFileService {
    public static let agentsDirectoryName = ".agents"
    public static let activeSkillsDirectoryName = "skills"
    public static let inactiveSkillsDirectoryName = "inactive-skills"

    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func activeDirectory(for project: SkillProject) -> URL {
        agentsDirectory(for: project).appendingPathComponent(Self.activeSkillsDirectoryName, isDirectory: true)
    }

    public func inactiveDirectory(for project: SkillProject) -> URL {
        agentsDirectory(for: project).appendingPathComponent(Self.inactiveSkillsDirectoryName, isDirectory: true)
    }

    public func scan(project: SkillProject) throws -> [SkillItem] {
        let activeSkills = try scanDirectory(activeDirectory(for: project), state: .active, project: project)
        let inactiveSkills = try scanDirectory(inactiveDirectory(for: project), state: .inactive, project: project)

        return (activeSkills + inactiveSkills).sorted { first, second in
            let nameCompare = first.name.localizedStandardCompare(second.name)
            if nameCompare == .orderedSame {
                return first.state.rawValue < second.state.rawValue
            }
            return nameCompare == .orderedAscending
        }
    }

    @discardableResult
    public func setEnabled(_ skill: SkillItem, enabled: Bool, in project: SkillProject) throws -> URL {
        let targetState: SkillState = enabled ? .active : .inactive
        guard skill.state != targetState else {
            return skill.url
        }

        let destinationDirectory = targetState == .active
            ? activeDirectory(for: project)
            : inactiveDirectory(for: project)
        let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)

        try validateSource(skill.url)
        try ensureDirectoryExists(destinationDirectory)
        try validateDestinationIsAvailable(destinationURL)
        try fileManager.moveItem(at: skill.url, to: destinationURL)

        return destinationURL
    }

    @discardableResult
    public func transfer(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode) throws -> URL {
        let destinationDirectory = activeDirectory(for: destinationProject)
        let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)

        try validateSource(skill.url)
        try ensureDirectoryExists(destinationDirectory)
        try validateDestinationIsAvailable(destinationURL)

        switch mode {
        case .copy:
            try fileManager.copyItem(at: skill.url, to: destinationURL)
        case .move:
            try fileManager.moveItem(at: skill.url, to: destinationURL)
        }

        return destinationURL
    }

    @discardableResult
    public func disableAll(in project: SkillProject) throws -> Int {
        let skillsToDisable = try scan(project: project).filter { $0.state == .active }
        guard !skillsToDisable.isEmpty else {
            return 0
        }

        let destinationDirectory = inactiveDirectory(for: project)
        try ensureDirectoryExists(destinationDirectory)

        for skill in skillsToDisable {
            try validateSource(skill.url)
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try validateDestinationIsAvailable(destinationURL)
        }

        for skill in skillsToDisable {
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try fileManager.moveItem(at: skill.url, to: destinationURL)
        }

        return skillsToDisable.count
    }

    public func ensureProjectSkillDirectories(for project: SkillProject) throws {
        try ensureDirectoryExists(activeDirectory(for: project))
        try ensureDirectoryExists(inactiveDirectory(for: project))
    }

    private func agentsDirectory(for project: SkillProject) -> URL {
        project.url.appendingPathComponent(Self.agentsDirectoryName, isDirectory: true)
    }

    private func scanDirectory(_ directory: URL, state: SkillState, project: SkillProject) throws -> [SkillItem] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        return entries.compactMap { url in
            guard isVisibleDirectory(url) else {
                return nil
            }

            return SkillItem(
                projectID: project.id,
                projectPath: project.path,
                name: url.lastPathComponent,
                state: state,
                url: url,
                summary: Self.summary(for: url)
            )
        }
    }

    private func validateSource(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SkillFileServiceError.sourceMissing(url)
        }
    }

    private func validateDestinationIsAvailable(_ url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw SkillFileServiceError.destinationExists(url)
        }
    }

    private func ensureDirectoryExists(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func isVisibleDirectory(_ url: URL) -> Bool {
        guard !url.lastPathComponent.hasPrefix(".") else {
            return false
        }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }

    private static func summary(for skillURL: URL) -> String? {
        let skillFileURL = skillURL.appendingPathComponent("SKILL.md")
        guard let contents = try? String(contentsOf: skillFileURL, encoding: .utf8) else {
            return nil
        }

        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        if let description = frontMatterValue(named: "description", in: lines) {
            return description
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("# ") }?
            .dropFirst(2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func frontMatterValue(named key: String, in lines: [String]) -> String? {
        let prefix = "\(key.lowercased()):"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix(prefix) else {
                continue
            }

            let value = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : value
        }

        return nil
    }
}
