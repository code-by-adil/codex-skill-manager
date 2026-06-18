import AppKit
import CodexSkillCore
import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var projects: [SkillProject]
    @Published private(set) var packages: [SkillPackage]
    @Published private(set) var skillsByProjectID: [UUID: [SkillItem]] = [:]
    @Published private(set) var projectErrors: [UUID: String] = [:]
    @Published private(set) var globalSkillsByLocationID: [GlobalSkillLocation.ID: [SkillItem]] = [:]
    @Published private(set) var globalErrors: [GlobalSkillLocation.ID: String] = [:]
    @Published private(set) var provider: SkillProvider
    @Published var selectedProjectID: UUID?
    @Published var selectedGlobalLocation: GlobalSkillLocation?
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let service: SkillFileService
    private let defaults: UserDefaults
    private let projectsKey = "projects.v1"
    private let packagesKey = "skillPackages.v1"
    private let selectedProjectKey = "selectedProjectID.v1"
    private let selectedSourceKey = "selectedSourceID.v1"
    private let providerKey = "provider.v1"

    init(service: SkillFileService = SkillFileService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults

        let storedProjects = Self.loadProjects(from: defaults, key: projectsKey)
        self.projects = storedProjects.isEmpty ? Self.defaultProjects() : storedProjects
        self.packages = Self.loadPackages(from: defaults, key: packagesKey)
        self.provider = Self.loadProvider(from: defaults, key: providerKey)

        if let selectedIDString = defaults.string(forKey: selectedProjectKey),
           let selectedID = UUID(uuidString: selectedIDString),
           self.projects.contains(where: { $0.id == selectedID }) {
            self.selectedProjectID = selectedID
        } else {
            self.selectedProjectID = self.projects.first?.id
        }

        if let selectedSourceID = defaults.string(forKey: selectedSourceKey) {
            applyStoredSelection(selectedSourceID)
        } else if self.projects.isEmpty {
            self.selectedGlobalLocation = .codex
        }

        saveProjects()
        saveSelectedSource()
        refresh()
    }

    var selectedSidebarItemID: String? {
        if let selectedGlobalLocation {
            return Self.sidebarID(for: selectedGlobalLocation)
        }

        if let selectedProjectID {
            return Self.sidebarID(for: selectedProjectID)
        }

        return nil
    }

    func sidebarID(for location: GlobalSkillLocation) -> String {
        Self.sidebarID(for: location)
    }

    func sidebarID(for project: SkillProject) -> String {
        Self.sidebarID(for: project.id)
    }

    var selectedProject: SkillProject? {
        guard let selectedProjectID else {
            return nil
        }
        return projects.first { $0.id == selectedProjectID }
    }

    func skills(for project: SkillProject) -> [SkillItem] {
        skillsByProjectID[project.id] ?? []
    }

    func globalSkills(for location: GlobalSkillLocation) -> [SkillItem] {
        globalSkillsByLocationID[location.id] ?? []
    }

    func activeCount(for project: SkillProject) -> Int {
        skills(for: project).filter(\.isEnabled).count
    }

    func inactiveCount(for project: SkillProject) -> Int {
        skills(for: project).filter { !$0.isEnabled }.count
    }

    func activeCount(for location: GlobalSkillLocation) -> Int {
        globalSkills(for: location).filter(\.isEnabled).count
    }

    func inactiveCount(for location: GlobalSkillLocation) -> Int {
        globalSkills(for: location).filter { !$0.isEnabled }.count
    }

    func packages(for project: SkillProject, provider: SkillProvider) -> [SkillPackage] {
        packages
            .filter { $0.scope.matches(project: project, provider: provider) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func packages(for location: GlobalSkillLocation) -> [SkillPackage] {
        packages
            .filter { $0.scope.matches(global: location) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func skills(in package: SkillPackage) -> [SkillItem] {
        let availableSkills = skills(for: package.scope)
        var skillsByName: [String: SkillItem] = [:]

        for skill in availableSkills {
            if let existing = skillsByName[skill.name], existing.isEnabled {
                continue
            }
            skillsByName[skill.name] = skill
        }

        return package.skillNames.compactMap { skillsByName[$0] }
    }

    func missingSkillNames(in package: SkillPackage) -> [String] {
        let availableNames = Set(skills(for: package.scope).map(\.name))
        return package.skillNames.filter { !availableNames.contains($0) }
    }

    func transferDestinations(for skill: SkillItem) -> [SkillProject] {
        projects.filter { $0.id != skill.projectID }
    }

    func selectProvider(_ provider: SkillProvider) {
        guard self.provider != provider else {
            return
        }

        self.provider = provider
        defaults.set(provider.rawValue, forKey: providerKey)
        refresh()
    }

    func selectSidebarItem(_ id: String?) {
        guard let id else {
            selectedGlobalLocation = nil
            selectedProjectID = nil
            saveSelectedSource()
            return
        }

        if let location = Self.globalLocation(from: id) {
            selectedGlobalLocation = location
            saveSelectedSource()
            return
        }

        if let projectID = Self.projectID(from: id),
           projects.contains(where: { $0.id == projectID }) {
            selectProject(projectID)
        }
    }

    func selectGlobalLocation(_ location: GlobalSkillLocation) {
        selectedGlobalLocation = location
        saveSelectedSource()
    }

    func selectProject(_ id: UUID?) {
        selectedGlobalLocation = nil
        selectedProjectID = id
        if let id {
            defaults.set(id.uuidString, forKey: selectedProjectKey)
        } else {
            defaults.removeObject(forKey: selectedProjectKey)
        }
        saveSelectedSource()
    }

    func addProjects(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        var didAdd = false
        for url in urls {
            let project = SkillProject(path: url.path)
            guard !projects.contains(where: { $0.path == project.path }) else {
                continue
            }
            projects.append(project)
            selectedGlobalLocation = nil
            selectedProjectID = project.id
            didAdd = true
        }

        if didAdd {
            saveProjects()
            saveSelectedSource()
            refresh()
        }
    }

    func createPackage(named name: String, skillNames: Set<String>, for project: SkillProject, provider: SkillProvider) {
        createPackage(named: name, skillNames: skillNames, scope: .project(project.id, provider: provider))
    }

    func createPackage(named name: String, skillNames: Set<String>, for location: GlobalSkillLocation) {
        createPackage(named: name, skillNames: skillNames, scope: .global(location))
    }

    func deletePackage(_ package: SkillPackage) {
        packages.removeAll { $0.id == package.id }
        savePackages()
    }

    func updatePackage(_ package: SkillPackage, name: String, skillNames: Set<String>) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedSkillNames = skillNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard !trimmedName.isEmpty, !sortedSkillNames.isEmpty,
              let index = packages.firstIndex(where: { $0.id == package.id }) else {
            return
        }

        packages[index].name = trimmedName
        packages[index].skillNames = sortedSkillNames
        packages[index].updatedAt = Date()
        savePackages()
    }

    func add(_ skill: SkillItem, to package: SkillPackage) {
        guard let index = packages.firstIndex(where: { $0.id == package.id }) else {
            return
        }

        var skillNames = Set(packages[index].skillNames)
        skillNames.insert(skill.name)
        packages[index].skillNames = skillNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        packages[index].updatedAt = Date()
        savePackages()
    }

    func remove(_ skill: SkillItem, from package: SkillPackage) {
        remove(skillNamed: skill.name, from: package)
    }

    func remove(skillNamed skillName: String, from package: SkillPackage) {
        removeSkillName(skillName, fromPackageID: package.id)
        savePackages()
    }

    func removeProject(_ project: SkillProject) {
        projects.removeAll { $0.id == project.id }
        packages.removeAll { package in
            package.scope.kind == .project && package.scope.projectID == project.id
        }
        skillsByProjectID[project.id] = nil
        projectErrors[project.id] = nil

        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
            if selectedProjectID == nil {
                selectedGlobalLocation = .codex
            }
        }

        saveProjects()
        savePackages()
        saveSelectedSource()
    }

    func refresh() {
        var nextSkills: [UUID: [SkillItem]] = [:]
        var nextErrors: [UUID: String] = [:]
        var nextGlobalSkills: [GlobalSkillLocation.ID: [SkillItem]] = [:]
        var nextGlobalErrors: [GlobalSkillLocation.ID: String] = [:]

        for location in GlobalSkillLocation.allCases {
            do {
                nextGlobalSkills[location.id] = try service.scanGlobal(location: location)
            } catch {
                nextGlobalSkills[location.id] = []
                nextGlobalErrors[location.id] = error.localizedDescription
            }
        }

        for project in projects {
            do {
                nextSkills[project.id] = try service.scan(project: project, provider: provider)
            } catch {
                nextSkills[project.id] = []
                nextErrors[project.id] = error.localizedDescription
            }
        }

        globalSkillsByLocationID = nextGlobalSkills
        globalErrors = nextGlobalErrors
        skillsByProjectID = nextSkills
        projectErrors = nextErrors
    }

    func toggle(_ skill: SkillItem) {
        guard let project = projects.first(where: { $0.id == skill.projectID }) else {
            return
        }

        do {
            try service.setEnabled(skill, enabled: !skill.isEnabled, in: project, provider: provider)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func toggleGlobal(_ skill: SkillItem, in location: GlobalSkillLocation) {
        do {
            try service.setGlobalEnabled(skill, enabled: !skill.isEnabled, in: location)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func toggle(_ skill: SkillItem, in package: SkillPackage) {
        do {
            try setEnabled(skill, enabled: !skill.isEnabled, in: package.scope)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transfer(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode) {
        do {
            try service.transfer(skill, to: destinationProject, mode: mode, provider: provider)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transfer(_ skill: SkillItem, in package: SkillPackage, to destinationProject: SkillProject, mode: SkillTransferMode) {
        do {
            let destinationProvider = package.scope.provider ?? .codex

            switch package.scope.kind {
            case .project:
                try service.transfer(skill, to: destinationProject, mode: mode, provider: destinationProvider)
            case .global:
                try service.transferGlobal(skill, to: destinationProject, mode: mode, provider: destinationProvider)
            }

            persistTransferredPackageSkill(
                skill,
                from: package,
                to: .project(destinationProject.id, provider: destinationProvider),
                mode: mode
            )
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transfer(_ skill: SkillItem, in package: SkillPackage, toProjectAt url: URL, mode: SkillTransferMode) {
        let normalizedProject = SkillProject(path: url.path)
        let destinationProject = projects.first { $0.path == normalizedProject.path } ?? normalizedProject
        transfer(skill, in: package, to: destinationProject, mode: mode)
    }

    func transfer(_ skill: SkillItem, toProjectAt url: URL, mode: SkillTransferMode) {
        let normalizedProject = SkillProject(path: url.path)
        let destinationProject = projects.first { $0.path == normalizedProject.path } ?? normalizedProject
        transfer(skill, to: destinationProject, mode: mode)
    }

    func transferGlobal(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode) {
        do {
            try service.transferGlobal(skill, to: destinationProject, mode: mode)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transferGlobal(_ skill: SkillItem, toProjectAt url: URL, mode: SkillTransferMode) {
        let normalizedProject = SkillProject(path: url.path)
        let destinationProject = projects.first { $0.path == normalizedProject.path } ?? normalizedProject
        transferGlobal(skill, to: destinationProject, mode: mode)
    }

    func transfer(_ skill: SkillItem, toGlobal location: GlobalSkillLocation, mode: SkillTransferMode) {
        do {
            try service.transfer(skill, toGlobal: location, mode: mode)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transfer(_ skill: SkillItem, in package: SkillPackage, toGlobal location: GlobalSkillLocation, mode: SkillTransferMode) {
        do {
            try service.transfer(skill, toGlobal: location, mode: mode)
            persistTransferredPackageSkill(
                skill,
                from: package,
                to: .global(location),
                mode: mode
            )
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func enablePackage(_ package: SkillPackage) {
        do {
            for skill in skills(in: package) where !skill.isEnabled {
                try setEnabled(skill, enabled: true, in: package.scope)
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func disablePackage(_ package: SkillPackage) {
        do {
            for skill in skills(in: package) where skill.isEnabled {
                try setEnabled(skill, enabled: false, in: package.scope)
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transferPackage(_ package: SkillPackage, to destinationProject: SkillProject, mode: SkillTransferMode) {
        do {
            let sourceSkills = skills(in: package)
            guard !sourceSkills.isEmpty else {
                return
            }
            let destinationProvider = package.scope.provider ?? .codex
            try service.transfer(sourceSkills, to: destinationProject, mode: mode, provider: destinationProvider)
            persistTransferredPackage(
                package,
                transferredSkillNames: sourceSkills.map(\.name),
                scope: .project(destinationProject.id, provider: destinationProvider),
                mode: mode
            )
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transferPackage(_ package: SkillPackage, toProjectAt url: URL, mode: SkillTransferMode) {
        let normalizedProject = SkillProject(path: url.path)
        let destinationProject = projects.first { $0.path == normalizedProject.path } ?? normalizedProject
        transferPackage(package, to: destinationProject, mode: mode)
    }

    func transferPackage(_ package: SkillPackage, toGlobal location: GlobalSkillLocation, mode: SkillTransferMode) {
        do {
            let sourceSkills = skills(in: package)
            guard !sourceSkills.isEmpty else {
                return
            }
            try service.transfer(sourceSkills, toGlobal: location, mode: mode)
            persistTransferredPackage(
                package,
                transferredSkillNames: sourceSkills.map(\.name),
                scope: .global(location),
                mode: mode
            )
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func delete(_ skill: SkillItem, from package: SkillPackage) {
        do {
            try service.delete(skill)
            removeSkillName(skill.name, fromPackagesMatching: package.scope)
            savePackages()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func delete(_ skill: SkillItem) {
        do {
            try service.delete(skill)
            removeSkillName(skill.name, fromPackagesMatching: scope(for: skill))
            savePackages()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func disableAll(in project: SkillProject) {
        do {
            try service.disableAll(in: project, provider: provider)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func enableAll(in project: SkillProject) {
        do {
            try service.enableAll(in: project, provider: provider)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func disableAllGlobal(in location: GlobalSkillLocation) {
        do {
            try service.disableAllGlobal(in: location)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func enableAllGlobal(in location: GlobalSkillLocation) {
        do {
            try service.enableAllGlobal(in: location)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func copyCodexSkillsToClaude(in project: SkillProject) {
        do {
            let result = try service.copyCodexSkillsToClaude(in: project)
            selectProvider(.claude)
            statusMessage = "Copied \(result.copiedTotal) skills to Claude. Skipped \(result.skippedExisting) existing skills."
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func revealDirectory(for project: SkillProject, state: SkillState) {
        let directory = state == .active
            ? service.activeDirectory(for: project, provider: provider)
            : service.inactiveDirectory(for: project, provider: provider)

        do {
            try service.ensureProjectSkillDirectories(for: project, provider: provider)
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealGlobalDirectory(for location: GlobalSkillLocation, state: SkillState) {
        let directory = state == .active
            ? service.globalActiveDirectory(for: location)
            : service.globalInactiveDirectory(for: location)

        do {
            try service.ensureGlobalSkillDirectories(for: location)
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createPackage(named name: String, skillNames: Set<String>, scope: SkillPackageScope) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedSkillNames = skillNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard !trimmedName.isEmpty, !sortedSkillNames.isEmpty else {
            return
        }

        packages.append(
            SkillPackage(
                name: trimmedName,
                scope: scope,
                skillNames: sortedSkillNames
            )
        )
        savePackages()
    }

    private func skills(for scope: SkillPackageScope) -> [SkillItem] {
        switch scope.kind {
        case .project:
            guard let projectID = scope.projectID,
                  let project = projects.first(where: { $0.id == projectID }) else {
                return []
            }
            return skillsByProjectID[project.id] ?? []
        case .global:
            guard let location = scope.globalLocation else {
                return []
            }
            return globalSkills(for: location)
        }
    }

    private func setEnabled(_ skill: SkillItem, enabled: Bool, in scope: SkillPackageScope) throws {
        switch scope.kind {
        case .project:
            guard let projectID = scope.projectID,
                  let project = projects.first(where: { $0.id == projectID }) else {
                return
            }
            try service.setEnabled(skill, enabled: enabled, in: project, provider: scope.provider ?? provider)
        case .global:
            guard let location = scope.globalLocation else {
                return
            }
            try service.setGlobalEnabled(skill, enabled: enabled, in: location)
        }
    }

    private func persistTransferredPackage(_ package: SkillPackage, transferredSkillNames: [String], scope: SkillPackageScope, mode: SkillTransferMode) {
        upsertPackage(named: package.name, skillNames: transferredSkillNames, scope: scope)

        if mode == .move {
            packages.removeAll { $0.id == package.id }
        }

        savePackages()
    }

    private func persistTransferredPackageSkill(_ skill: SkillItem, from package: SkillPackage, to scope: SkillPackageScope, mode: SkillTransferMode) {
        upsertPackage(named: package.name, skillNames: [skill.name], scope: scope)

        if mode == .move {
            removeSkillName(skill.name, fromPackagesMatching: package.scope)
        }

        savePackages()
    }

    private func upsertPackage(named name: String, skillNames: [String], scope: SkillPackageScope) {
        let uniqueSkillNames = Set(skillNames).sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        if let index = packages.firstIndex(where: { $0.scope == scope && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            let mergedSkillNames = Set(packages[index].skillNames).union(uniqueSkillNames)
            packages[index].skillNames = mergedSkillNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            packages[index].updatedAt = Date()
        } else {
            packages.append(
                SkillPackage(
                    name: name,
                    scope: scope,
                    skillNames: uniqueSkillNames
                )
            )
        }
    }

    private func removeSkillName(_ skillName: String, fromPackageID packageID: UUID) {
        guard let index = packages.firstIndex(where: { $0.id == packageID }) else {
            return
        }

        packages[index].skillNames.removeAll { $0 == skillName }
        packages[index].updatedAt = Date()
    }

    private func removeSkillName(_ skillName: String, fromPackagesMatching scope: SkillPackageScope) {
        for index in packages.indices where packages[index].scope == scope {
            let oldCount = packages[index].skillNames.count
            packages[index].skillNames.removeAll { $0 == skillName }
            if packages[index].skillNames.count != oldCount {
                packages[index].updatedAt = Date()
            }
        }
    }

    private func scope(for skill: SkillItem) -> SkillPackageScope {
        if let location = GlobalSkillLocation.allCases.first(where: { $0.storageID == skill.projectID }) {
            return .global(location)
        }

        return .project(skill.projectID, provider: skill.provider)
    }

    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            defaults.set(data, forKey: projectsKey)
            if let selectedProjectID {
                defaults.set(selectedProjectID.uuidString, forKey: selectedProjectKey)
            } else {
                defaults.removeObject(forKey: selectedProjectKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePackages() {
        do {
            let data = try JSONEncoder().encode(packages)
            defaults.set(data, forKey: packagesKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSelectedSource() {
        if let selectedSidebarItemID {
            defaults.set(selectedSidebarItemID, forKey: selectedSourceKey)
        } else {
            defaults.removeObject(forKey: selectedSourceKey)
        }

        if let selectedProjectID {
            defaults.set(selectedProjectID.uuidString, forKey: selectedProjectKey)
        } else {
            defaults.removeObject(forKey: selectedProjectKey)
        }
    }

    private func applyStoredSelection(_ id: String) {
        if let location = Self.globalLocation(from: id) {
            selectedGlobalLocation = location
            return
        }

        if let projectID = Self.projectID(from: id),
           projects.contains(where: { $0.id == projectID }) {
            selectedGlobalLocation = nil
            selectedProjectID = projectID
            return
        }

        if projects.isEmpty {
            selectedGlobalLocation = .codex
        }
    }

    private static let globalSelectionPrefix = "global:"
    private static let projectSelectionPrefix = "project:"

    private static func sidebarID(for location: GlobalSkillLocation) -> String {
        "\(globalSelectionPrefix)\(location.rawValue)"
    }

    private static func sidebarID(for projectID: UUID) -> String {
        "\(projectSelectionPrefix)\(projectID.uuidString)"
    }

    private static func globalLocation(from id: String) -> GlobalSkillLocation? {
        guard id.hasPrefix(globalSelectionPrefix) else {
            return nil
        }

        let rawValue = String(id.dropFirst(globalSelectionPrefix.count))
        return GlobalSkillLocation(rawValue: rawValue)
    }

    private static func projectID(from id: String) -> UUID? {
        guard id.hasPrefix(projectSelectionPrefix) else {
            return nil
        }

        let rawValue = String(id.dropFirst(projectSelectionPrefix.count))
        return UUID(uuidString: rawValue)
    }

    private static func loadProjects(from defaults: UserDefaults, key: String) -> [SkillProject] {
        guard let data = defaults.data(forKey: key),
              let projects = try? JSONDecoder().decode([SkillProject].self, from: data) else {
            return []
        }

        return projects
    }

    private static func loadPackages(from defaults: UserDefaults, key: String) -> [SkillPackage] {
        guard let data = defaults.data(forKey: key),
              let packages = try? JSONDecoder().decode([SkillPackage].self, from: data) else {
            return []
        }

        return packages
    }

    private static func loadProvider(from defaults: UserDefaults, key: String) -> SkillProvider {
        guard let rawValue = defaults.string(forKey: key),
              let provider = SkillProvider(rawValue: rawValue) else {
            return .codex
        }

        return provider
    }

    private static func defaultProjects() -> [SkillProject] {
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let knownProjectURL = homeURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("ielts-react-expo-monorepo", isDirectory: true)

        let candidates = [
            knownProjectURL,
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        ]

        return candidates.reduce(into: [SkillProject]()) { result, url in
            let agentsURL = url.appendingPathComponent(SkillFileService.agentsDirectoryName, isDirectory: true)
            let claudeURL = url.appendingPathComponent(SkillFileService.claudeDirectoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: agentsURL.path) || fileManager.fileExists(atPath: claudeURL.path) else {
                return
            }

            let project = SkillProject(path: url.path)
            guard !result.contains(where: { $0.path == project.path }) else {
                return
            }
            result.append(project)
        }
    }
}
