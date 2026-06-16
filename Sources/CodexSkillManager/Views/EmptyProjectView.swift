import SwiftUI

struct EmptyProjectView: View {
    @ObservedObject var store: SkillStore

    var body: some View {
        ContentUnavailableView {
            Label("No Project Selected", systemImage: "folder.badge.plus")
        } description: {
            Text("Add a project folder that contains .agents/skills.")
        } actions: {
            Button("Add Project...") {
                store.addProjects(ProjectOpenPanel.selectProjects())
            }
        }
    }
}
