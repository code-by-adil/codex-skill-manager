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

public struct SkillConversionResult: Equatable, Sendable {
    public let copiedEnabled: Int
    public let copiedDisabled: Int
    public let skippedExisting: Int

    public var copiedTotal: Int {
        copiedEnabled + copiedDisabled
    }
}

public struct SkillFileService {
    public static let agentsDirectoryName = ".agents"
    public static let claudeDirectoryName = ".claude"
    public static let activeSkillsDirectoryName = "skills"
    public static let inactiveSkillsDirectoryName = "inactive-skills"

    public var fileManager: FileManager
    public var homeDirectoryURL: URL
    public var centralInactiveRootURL: URL

    public init(fileManager: FileManager = .default, centralInactiveRootURL: URL? = nil, homeDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser
        self.centralInactiveRootURL = centralInactiveRootURL ?? Self.defaultCentralInactiveRootURL(fileManager: fileManager)
    }

    public func activeDirectory(for project: SkillProject, provider: SkillProvider = .codex) -> URL {
        rootDirectory(for: project, provider: provider)
            .appendingPathComponent(Self.activeSkillsDirectoryName, isDirectory: true)
    }

    public func inactiveDirectory(for project: SkillProject, provider: SkillProvider = .codex) -> URL {
        centralInactiveRootURL
            .appendingPathComponent(provider.rawValue, isDirectory: true)
            .appendingPathComponent(Self.projectStorageKey(for: project), isDirectory: true)
            .appendingPathComponent(Self.inactiveSkillsDirectoryName, isDirectory: true)
    }

    public func globalRootDirectory(for location: GlobalSkillLocation) -> URL {
        homeDirectoryURL.appendingPathComponent(location.configurationDirectoryName, isDirectory: true)
    }

    public func globalActiveDirectory(for location: GlobalSkillLocation) -> URL {
        globalRootDirectory(for: location)
            .appendingPathComponent(Self.activeSkillsDirectoryName, isDirectory: true)
    }

    public func globalInactiveDirectory(for location: GlobalSkillLocation) -> URL {
        centralInactiveRootURL
            .appendingPathComponent("global", isDirectory: true)
            .appendingPathComponent(location.rawValue, isDirectory: true)
            .appendingPathComponent(Self.inactiveSkillsDirectoryName, isDirectory: true)
    }

    public func scan(project: SkillProject, provider: SkillProvider = .codex) throws -> [SkillItem] {
        try migrateLegacyInactiveSkillsIfNeeded(project: project, provider: provider)

        let activeSkills = try scanDirectory(activeDirectory(for: project, provider: provider), state: .active, provider: provider, project: project)
        let inactiveSkills = try scanDirectory(inactiveDirectory(for: project, provider: provider), state: .inactive, provider: provider, project: project)

        return sorted(activeSkills + inactiveSkills)
    }

    public func scanGlobal(location: GlobalSkillLocation) throws -> [SkillItem] {
        let source = globalProject(for: location)
        let activeSkills = try scanDirectory(globalActiveDirectory(for: location), state: .active, provider: .codex, project: source)
        let inactiveSkills = try scanDirectory(globalInactiveDirectory(for: location), state: .inactive, provider: .codex, project: source)

        return sorted(activeSkills + inactiveSkills)
    }

    private func sorted(_ skills: [SkillItem]) -> [SkillItem] {
        skills.sorted { first, second in
            let nameCompare = first.name.localizedStandardCompare(second.name)
            if nameCompare == .orderedSame {
                return first.state.rawValue < second.state.rawValue
            }
            return nameCompare == .orderedAscending
        }
    }

    @discardableResult
    public func setEnabled(_ skill: SkillItem, enabled: Bool, in project: SkillProject, provider: SkillProvider = .codex) throws -> URL {
        let targetState: SkillState = enabled ? .active : .inactive
        guard skill.state != targetState else {
            return skill.url
        }

        let destinationDirectory = targetState == .active
            ? activeDirectory(for: project, provider: provider)
            : inactiveDirectory(for: project, provider: provider)
        let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)

        try validateSource(skill.url)
        try ensureDirectoryExists(destinationDirectory)
        try validateDestinationIsAvailable(destinationURL)
        try fileManager.moveItem(at: skill.url, to: destinationURL)

        return destinationURL
    }

    @discardableResult
    public func setGlobalEnabled(_ skill: SkillItem, enabled: Bool, in location: GlobalSkillLocation) throws -> URL {
        let targetState: SkillState = enabled ? .active : .inactive
        guard skill.state != targetState else {
            return skill.url
        }

        let destinationDirectory = targetState == .active
            ? globalActiveDirectory(for: location)
            : globalInactiveDirectory(for: location)
        let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)

        try validateSource(skill.url)
        try ensureDirectoryExists(destinationDirectory)
        try validateDestinationIsAvailable(destinationURL)
        try fileManager.moveItem(at: skill.url, to: destinationURL)

        return destinationURL
    }

    @discardableResult
    public func transfer(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode, provider: SkillProvider = .codex) throws -> URL {
        let destinationDirectory = activeDirectory(for: destinationProject, provider: provider)
        return try transfer(skill, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func transfer(_ skills: [SkillItem], to destinationProject: SkillProject, mode: SkillTransferMode, provider: SkillProvider = .codex) throws -> [URL] {
        let destinationDirectory = activeDirectory(for: destinationProject, provider: provider)
        return try transfer(skills, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func transferGlobal(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode, provider: SkillProvider = .codex) throws -> URL {
        let destinationDirectory = activeDirectory(for: destinationProject, provider: provider)
        return try transfer(skill, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func transferGlobal(_ skills: [SkillItem], to destinationProject: SkillProject, mode: SkillTransferMode, provider: SkillProvider = .codex) throws -> [URL] {
        let destinationDirectory = activeDirectory(for: destinationProject, provider: provider)
        return try transfer(skills, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func transfer(_ skill: SkillItem, toGlobal location: GlobalSkillLocation, mode: SkillTransferMode) throws -> URL {
        let destinationDirectory = globalActiveDirectory(for: location)
        return try transfer(skill, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func transfer(_ skills: [SkillItem], toGlobal location: GlobalSkillLocation, mode: SkillTransferMode) throws -> [URL] {
        let destinationDirectory = globalActiveDirectory(for: location)
        return try transfer(skills, toActiveDirectory: destinationDirectory, mode: mode)
    }

    @discardableResult
    public func delete(_ skill: SkillItem) throws -> URL {
        try validateSource(skill.url)
        try fileManager.removeItem(at: skill.url)
        return skill.url
    }

    @discardableResult
    public func disableAll(in project: SkillProject, provider: SkillProvider = .codex) throws -> Int {
        let skillsToDisable = try scan(project: project, provider: provider).filter { $0.state == .active }
        guard !skillsToDisable.isEmpty else {
            return 0
        }

        let destinationDirectory = inactiveDirectory(for: project, provider: provider)
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

    @discardableResult
    public func disableAllGlobal(in location: GlobalSkillLocation) throws -> Int {
        let skillsToDisable = try scanGlobal(location: location).filter { $0.state == .active }
        guard !skillsToDisable.isEmpty else {
            return 0
        }

        let destinationDirectory = globalInactiveDirectory(for: location)
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

    @discardableResult
    public func enableAll(in project: SkillProject, provider: SkillProvider = .codex) throws -> Int {
        let skillsToEnable = try scan(project: project, provider: provider).filter { $0.state == .inactive }
        guard !skillsToEnable.isEmpty else {
            return 0
        }

        let destinationDirectory = activeDirectory(for: project, provider: provider)
        try ensureDirectoryExists(destinationDirectory)

        for skill in skillsToEnable {
            try validateSource(skill.url)
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try validateDestinationIsAvailable(destinationURL)
        }

        for skill in skillsToEnable {
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try fileManager.moveItem(at: skill.url, to: destinationURL)
        }

        return skillsToEnable.count
    }

    @discardableResult
    public func enableAllGlobal(in location: GlobalSkillLocation) throws -> Int {
        let skillsToEnable = try scanGlobal(location: location).filter { $0.state == .inactive }
        guard !skillsToEnable.isEmpty else {
            return 0
        }

        let destinationDirectory = globalActiveDirectory(for: location)
        try ensureDirectoryExists(destinationDirectory)

        for skill in skillsToEnable {
            try validateSource(skill.url)
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try validateDestinationIsAvailable(destinationURL)
        }

        for skill in skillsToEnable {
            let destinationURL = destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
            try fileManager.moveItem(at: skill.url, to: destinationURL)
        }

        return skillsToEnable.count
    }

    @discardableResult
    public func copyCodexSkillsToClaude(in project: SkillProject) throws -> SkillConversionResult {
        let activeCodexSkills = try scan(project: project, provider: .codex).filter { $0.state == .active }
        let inactiveCodexSkills = try scan(project: project, provider: .codex).filter { $0.state == .inactive }
        let activeClaudeDirectory = activeDirectory(for: project, provider: .claude)
        let inactiveClaudeDirectory = inactiveDirectory(for: project, provider: .claude)

        try ensureDirectoryExists(activeClaudeDirectory)
        try ensureDirectoryExists(inactiveClaudeDirectory)

        var copiedEnabled = 0
        var copiedDisabled = 0
        var skippedExisting = 0

        for skill in activeCodexSkills {
            let destinationURL = activeClaudeDirectory.appendingPathComponent(skill.name, isDirectory: true)
            if claudeSkillExists(named: skill.name, in: project) {
                skippedExisting += 1
                continue
            }
            try fileManager.copyItem(at: skill.url, to: destinationURL)
            copiedEnabled += 1
        }

        for skill in inactiveCodexSkills {
            let destinationURL = inactiveClaudeDirectory.appendingPathComponent(skill.name, isDirectory: true)
            if claudeSkillExists(named: skill.name, in: project) {
                skippedExisting += 1
                continue
            }
            try fileManager.copyItem(at: skill.url, to: destinationURL)
            copiedDisabled += 1
        }

        return SkillConversionResult(
            copiedEnabled: copiedEnabled,
            copiedDisabled: copiedDisabled,
            skippedExisting: skippedExisting
        )
    }

    public func ensureProjectSkillDirectories(for project: SkillProject, provider: SkillProvider = .codex) throws {
        try ensureDirectoryExists(activeDirectory(for: project, provider: provider))
        try ensureDirectoryExists(inactiveDirectory(for: project, provider: provider))
    }

    public func ensureGlobalSkillDirectories(for location: GlobalSkillLocation) throws {
        try ensureDirectoryExists(globalActiveDirectory(for: location))
        try ensureDirectoryExists(globalInactiveDirectory(for: location))
    }

    private func rootDirectory(for project: SkillProject, provider: SkillProvider) -> URL {
        project.url.appendingPathComponent(provider.configurationDirectoryName, isDirectory: true)
    }

    private func globalProject(for location: GlobalSkillLocation) -> SkillProject {
        SkillProject(
            id: location.storageID,
            name: location.label,
            path: globalRootDirectory(for: location).path
        )
    }

    @discardableResult
    private func transfer(_ skill: SkillItem, toActiveDirectory destinationDirectory: URL, mode: SkillTransferMode) throws -> URL {
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
    private func transfer(_ skills: [SkillItem], toActiveDirectory destinationDirectory: URL, mode: SkillTransferMode) throws -> [URL] {
        guard !skills.isEmpty else {
            return []
        }

        let destinationURLs = skills.map { skill in
            destinationDirectory.appendingPathComponent(skill.name, isDirectory: true)
        }

        try ensureDirectoryExists(destinationDirectory)

        for skill in skills {
            try validateSource(skill.url)
        }

        for destinationURL in destinationURLs {
            try validateDestinationIsAvailable(destinationURL)
        }

        for (skill, destinationURL) in zip(skills, destinationURLs) {
            switch mode {
            case .copy:
                try fileManager.copyItem(at: skill.url, to: destinationURL)
            case .move:
                try fileManager.moveItem(at: skill.url, to: destinationURL)
            }
        }

        return destinationURLs
    }

    private func legacyInactiveDirectory(for project: SkillProject, provider: SkillProvider) -> URL {
        rootDirectory(for: project, provider: provider)
            .appendingPathComponent(Self.inactiveSkillsDirectoryName, isDirectory: true)
    }

    private func migrateLegacyInactiveSkillsIfNeeded(project: SkillProject, provider: SkillProvider) throws {
        let legacyDirectory = legacyInactiveDirectory(for: project, provider: provider)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        let destinationDirectory = inactiveDirectory(for: project, provider: provider)
        try ensureDirectoryExists(destinationDirectory)

        let entries = try fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        for url in entries where isVisibleDirectory(url) {
            let destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: true)
            guard !fileManager.fileExists(atPath: destinationURL.path) else {
                continue
            }
            try fileManager.moveItem(at: url, to: destinationURL)
        }
    }

    private func scanDirectory(_ directory: URL, state: SkillState, provider: SkillProvider, project: SkillProject) throws -> [SkillItem] {
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
                provider: provider,
                name: url.lastPathComponent,
                state: state,
                url: url,
                summary: Self.summary(for: url)
            )
        }
    }

    private func claudeSkillExists(named name: String, in project: SkillProject) -> Bool {
        let activeURL = activeDirectory(for: project, provider: .claude).appendingPathComponent(name, isDirectory: true)
        let inactiveURL = inactiveDirectory(for: project, provider: .claude).appendingPathComponent(name, isDirectory: true)
        return fileManager.fileExists(atPath: activeURL.path) || fileManager.fileExists(atPath: inactiveURL.path)
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

    private static func defaultCentralInactiveRootURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupportURL
            .appendingPathComponent("CodexSkillManager", isDirectory: true)
            .appendingPathComponent("InactiveSkills", isDirectory: true)
    }

    private static func projectStorageKey(for project: SkillProject) -> String {
        Data(project.path.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}
