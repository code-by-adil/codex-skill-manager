import CodexSkillCore
import SwiftUI

struct ProjectSidebarView: View {
    @ObservedObject var store: SkillStore
    @State private var projectPendingRemoval: SkillProject?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: {
                store.selectedSidebarItemID
            }, set: { newValue in
                store.selectSidebarItem(newValue)
            })) {
                Section("Global Skills") {
                    ForEach(GlobalSkillLocation.allCases) { location in
                        GlobalSidebarRow(
                            location: location,
                            enabledCount: store.activeCount(for: location),
                            disabledCount: store.inactiveCount(for: location),
                            hasError: store.globalErrors[location.id] != nil
                        )
                        .tag(store.sidebarID(for: location))
                        .contextMenu {
                            Button("Reveal Enabled Skills") {
                                store.revealGlobalDirectory(for: location, state: .active)
                            }
                            Button("Reveal Disabled Skills") {
                                store.revealGlobalDirectory(for: location, state: .inactive)
                            }
                        }
                    }
                }

                Section("Projects") {
                    ForEach(store.projects) { project in
                        ProjectSidebarRow(
                            project: project,
                            enabledCount: store.activeCount(for: project),
                            disabledCount: store.inactiveCount(for: project),
                            hasError: store.projectErrors[project.id] != nil,
                            onRemove: {
                                projectPendingRemoval = project
                            }
                        )
                        .tag(store.sidebarID(for: project))
                        .contextMenu {
                            Button("Reveal Enabled Skills") {
                                store.revealDirectory(for: project, state: .active)
                            }
                            Button("Reveal Disabled Skills") {
                                store.revealDirectory(for: project, state: .inactive)
                            }
                            Divider()
                            Button("Remove Project", role: .destructive) {
                                projectPendingRemoval = project
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(spacing: 8) {
                Button {
                    store.addProjects(ProjectOpenPanel.selectProjects())
                } label: {
                    Label("Add Project...", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Add project")

                HStack {
                    Text(projectCountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }
            }
            .padding(10)
        }
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

    private var projectCountLabel: String {
        let count = store.projects.count
        return count == 1 ? "1 project" : "\(count) projects"
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

private struct GlobalSidebarRow: View {
    let location: GlobalSkillLocation
    let enabledCount: Int
    let disabledCount: Int
    let hasError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImageName)
                .foregroundStyle(hasError ? .orange : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(location.label)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(enabledCount) on, \(disabledCount) off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var systemImageName: String {
        if hasError {
            return "exclamationmark.triangle"
        }

        switch location {
        case .codex:
            return "globe"
        case .agents:
            return "person.2"
        }
    }
}

private struct ProjectSidebarRow: View {
    let project: SkillProject
    let enabledCount: Int
    let disabledCount: Int
    let hasError: Bool
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hasError ? "exclamationmark.triangle" : "folder")
                .foregroundStyle(hasError ? .orange : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(enabledCount) on, \(disabledCount) off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .opacity(isHovering ? 1 : 0)
            .disabled(!isHovering)
            .accessibilityHidden(!isHovering)
            .help("Remove project from manager")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}
