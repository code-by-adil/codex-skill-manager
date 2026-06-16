import CodexSkillCore
import SwiftUI

struct ProjectDetailView: View {
    @ObservedObject var store: SkillStore
    let project: SkillProject

    @State private var filter: SkillFilter = .all
    @State private var searchText = ""

    private var visibleSkills: [SkillItem] {
        store.skills(for: project)
            .filter { skill in
                switch filter {
                case .all:
                    true
                case .enabled:
                    skill.isEnabled
                case .disabled:
                    !skill.isEnabled
                }
            }
            .filter { skill in
                guard !searchText.isEmpty else {
                    return true
                }

                let haystack = [skill.name, skill.summary ?? ""].joined(separator: " ")
                return haystack.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(store: store, project: project)

            Divider()

            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(SkillFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField("Search skills", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding()

            if let projectError = store.projectErrors[project.id] {
                Label(projectError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if visibleSkills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills", systemImage: "wand.and.stars.inverse")
                } description: {
                    Text("No project skills match the current view.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleSkills) { skill in
                    SkillRowView(
                        skill: skill,
                        destinationProjects: store.transferDestinations(for: skill),
                        onToggle: { store.toggle(skill) },
                        onTransfer: { destinationProject, mode in
                            store.transfer(skill, to: destinationProject, mode: mode)
                        },
                        onChooseDestination: { mode in
                            if let destinationURL = ProjectOpenPanel.selectTransferDestination() {
                                store.transfer(skill, toProjectAt: destinationURL, mode: mode)
                            }
                        }
                    )
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(project.name)
    }
}

private struct ProjectHeaderView: View {
    @ObservedObject var store: SkillStore
    let project: SkillProject

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)

                    Text(project.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    CountBadge(title: "Enabled", count: store.activeCount(for: project), color: .green)
                    CountBadge(title: "Disabled", count: store.inactiveCount(for: project), color: .secondary)
                }
            }

            HStack(spacing: 10) {
                Picker("Mode", selection: Binding(get: {
                    store.provider
                }, set: { provider in
                    store.selectProvider(provider)
                })) {
                    ForEach(SkillProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
                .help("Choose which project skill directory to manage")

                Spacer(minLength: 12)

                HeaderActionButton(
                    title: "Convert to Claude",
                    systemImage: "arrow.triangle.2.circlepath",
                    help: "Copy Codex skills to this project's Claude skill folders"
                ) {
                    store.copyCodexSkillsToClaude(in: project)
                }

                if store.activeCount(for: project) > 0 {
                    HeaderActionButton(
                        title: "Disable All",
                        systemImage: "archivebox.fill",
                        help: "Move all enabled skills to inactive skills"
                    ) {
                        store.disableAll(in: project)
                    }
                } else {
                    HeaderActionButton(
                        title: "Enable All",
                        systemImage: "checkmark.circle.fill",
                        help: "Move all disabled skills back to active skills",
                        isDisabled: store.inactiveCount(for: project) == 0
                    ) {
                        store.enableAll(in: project)
                    }
                }

                Menu {
                    Button("Enabled Skills Folder") {
                        store.revealDirectory(for: project, state: .active)
                    }

                    Button("Disabled Skills Folder") {
                        store.revealDirectory(for: project, state: .inactive)
                    }
                } label: {
                    Label("Folders", systemImage: "folder")
                }
                .menuStyle(.button)
                .controlSize(.regular)
                .help("Reveal skill folders")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct CountBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 98)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct HeaderActionButton: View {
    let title: String
    let systemImage: String
    let help: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isDisabled)
        .help(help)
    }
}
