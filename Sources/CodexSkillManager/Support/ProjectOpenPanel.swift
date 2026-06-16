import AppKit
import Foundation

enum ProjectOpenPanel {
    @MainActor
    static func selectProjects() -> [URL] {
        let panel = makeProjectPanel()
        panel.title = "Add Codex Projects"
        panel.prompt = "Add Project"
        panel.message = "Choose project folders that contain project-level Codex skills."
        panel.allowsMultipleSelection = true

        return panel.runModal() == .OK ? panel.urls : []
    }

    @MainActor
    static func selectTransferDestination() -> URL? {
        let panel = makeProjectPanel()
        panel.title = "Choose Destination Project"
        panel.prompt = "Choose Project"
        panel.message = "Choose a project folder. The skill will be placed in its .agents/skills folder."
        panel.allowsMultipleSelection = false

        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    private static func makeProjectPanel() -> NSOpenPanel {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false

        let developerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Developer", isDirectory: true)
        if FileManager.default.fileExists(atPath: developerURL.path) {
            panel.directoryURL = developerURL
        }

        return panel
    }
}
