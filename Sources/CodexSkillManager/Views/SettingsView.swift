import CodexSkillCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SkillStore
    @State private var projectPendingRemoval: SkillProject?

    var body: some View {
        Form {
            Section("Projects") {
                ForEach(store.projects) { project in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(project.name)
                            Text(project.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button {
                            projectPendingRemoval = project
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove project")
                    }
                }

                Button("Add Project...") {
                    store.addProjects(ProjectOpenPanel.selectProjects())
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 360)
        .confirmationDialog(
            "Remove Project?",
            isPresented: removalConfirmationBinding,
            titleVisibility: .visible
        ) {
            if let project = projectPendingRemoval {
                Button("Remove from Manager", role: .destructive) {
                    store.removeProject(project)
                    projectPendingRemoval = nil
                }
            }

            Button("Cancel", role: .cancel) {
                projectPendingRemoval = nil
            }
        } message: {
            if let project = projectPendingRemoval {
                Text("Remove \(project.name) from Codex Skill Manager? This does not delete the project folder or any skills.")
            }
        }
    }

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { projectPendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    projectPendingRemoval = nil
                }
            }
        )
    }
}
