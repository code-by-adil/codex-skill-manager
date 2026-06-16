import AppKit
import Foundation

enum ProjectOpenPanel {
    @MainActor
    static func selectProjects() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Add Codex Project"
        panel.prompt = "Add Project"
        panel.message = "Choose project folders that contain project-level Codex skills."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        let developerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Developer", isDirectory: true)
        if FileManager.default.fileExists(atPath: developerURL.path) {
            panel.directoryURL = developerURL
        }

        return panel.runModal() == .OK ? panel.urls : []
    }
}
