import AppKit
import CodexSkillCore
import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var projects: [SkillProject]
    @Published private(set) var skillsByProjectID: [UUID: [SkillItem]] = [:]
    @Published private(set) var projectErrors: [UUID: String] = [:]
    @Published var selectedProjectID: UUID?
    @Published var errorMessage: String?

    private let service: SkillFileService
    private let defaults: UserDefaults
    private let projectsKey = "projects.v1"
    private let selectedProjectKey = "selectedProjectID.v1"

    init(service: SkillFileService = SkillFileService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults

        let storedProjects = Self.loadProjects(from: defaults, key: projectsKey)
        self.projects = storedProjects.isEmpty ? Self.defaultProjects() : storedProjects

        if let selectedIDString = defaults.string(forKey: selectedProjectKey),
           let selectedID = UUID(uuidString: selectedIDString),
           self.projects.contains(where: { $0.id == selectedID }) {
            self.selectedProjectID = selectedID
        } else {
            self.selectedProjectID = self.projects.first?.id
        }

        saveProjects()
        refresh()
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

    func activeCount(for project: SkillProject) -> Int {
        skills(for: project).filter(\.isEnabled).count
    }

    func inactiveCount(for project: SkillProject) -> Int {
        skills(for: project).filter { !$0.isEnabled }.count
    }

    func transferDestinations(for skill: SkillItem) -> [SkillProject] {
        projects.filter { $0.id != skill.projectID }
    }

    func selectProject(_ id: UUID?) {
        selectedProjectID = id
        if let id {
            defaults.set(id.uuidString, forKey: selectedProjectKey)
        } else {
            defaults.removeObject(forKey: selectedProjectKey)
        }
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
            selectedProjectID = project.id
            didAdd = true
        }

        if didAdd {
            saveProjects()
            refresh()
        }
    }

    func removeProject(_ project: SkillProject) {
        projects.removeAll { $0.id == project.id }
        skillsByProjectID[project.id] = nil
        projectErrors[project.id] = nil

        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
        }

        saveProjects()
    }

    func refresh() {
        var nextSkills: [UUID: [SkillItem]] = [:]
        var nextErrors: [UUID: String] = [:]

        for project in projects {
            do {
                nextSkills[project.id] = try service.scan(project: project)
            } catch {
                nextSkills[project.id] = []
                nextErrors[project.id] = error.localizedDescription
            }
        }

        skillsByProjectID = nextSkills
        projectErrors = nextErrors
    }

    func toggle(_ skill: SkillItem) {
        guard let project = projects.first(where: { $0.id == skill.projectID }) else {
            return
        }

        do {
            try service.setEnabled(skill, enabled: !skill.isEnabled, in: project)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func transfer(_ skill: SkillItem, to destinationProject: SkillProject, mode: SkillTransferMode) {
        do {
            try service.transfer(skill, to: destinationProject, mode: mode)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func disableAll(in project: SkillProject) {
        do {
            try service.disableAll(in: project)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func revealDirectory(for project: SkillProject, state: SkillState) {
        let directory = state == .active
            ? service.activeDirectory(for: project)
            : service.inactiveDirectory(for: project)

        do {
            try service.ensureProjectSkillDirectories(for: project)
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            defaults.set(data, forKey: projectsKey)
            if let selectedProjectID {
                defaults.set(selectedProjectID.uuidString, forKey: selectedProjectKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func loadProjects(from defaults: UserDefaults, key: String) -> [SkillProject] {
        guard let data = defaults.data(forKey: key),
              let projects = try? JSONDecoder().decode([SkillProject].self, from: data) else {
            return []
        }

        return projects
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
            guard fileManager.fileExists(atPath: agentsURL.path) else {
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
