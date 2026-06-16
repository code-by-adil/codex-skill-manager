import AppKit
import SwiftUI

@main
struct CodexSkillManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SkillStore()

    var body: some Scene {
        WindowGroup("Codex Skill Manager", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 920, minHeight: 580)
        }
        .defaultSize(width: 1040, height: 680)

        Settings {
            SettingsView(store: store)
        }

        MenuBarExtra("Codex Skills", systemImage: "wand.and.stars") {
            MenuBarPanelView(store: store)
        }
        .menuBarExtraStyle(.window)

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Project...") {
                    store.addProjects(ProjectOpenPanel.selectProjects())
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("Skills") {
                Button("Refresh") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
