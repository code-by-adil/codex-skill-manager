import CodexSkillCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: SkillStore
    @Environment(\.openWindow) private var openWindow

    @State private var filter: SkillFilter = .all
    @State private var searchText = ""

    private var visibleSkills: [SkillItem] {
        guard let project = store.selectedProject else {
            return []
        }

        return store.skills(for: project)
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
                return skill.name.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Codex Skills", systemImage: "wand.and.stars")
                    .font(.headline)

                Spacer()

                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open manager")
            }

            if store.projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder.badge.plus")
                } actions: {
                    Button("Add Project...") {
                        store.addProjects(ProjectOpenPanel.selectProjects())
                    }
                }
            } else {
                Picker("Project", selection: Binding(get: {
                    store.selectedProjectID
                }, set: { newValue in
                    store.selectProject(newValue)
                })) {
                    ForEach(store.projects) { project in
                        Text(shortText(project.name)).tag(Optional(project.id))
                    }
                }

                HStack {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }

                Picker("Filter", selection: $filter) {
                    ForEach(SkillFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                if visibleSkills.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills", systemImage: "wand.and.stars.inverse")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(visibleSkills) { skill in
                                MenuSkillRow(
                                    skill: skill,
                                    destinationProjects: store.transferDestinations(for: skill),
                                    onToggle: {
                                        store.toggle(skill)
                                    },
                                    onTransfer: { destinationProject, mode in
                                        store.transfer(skill, to: destinationProject, mode: mode)
                                    }
                                )
                            }
                        }
                    }
                }

                if let project = store.selectedProject {
                    Divider()

                    HStack {
                        Text("\(store.activeCount(for: project)) on")
                        Text("\(store.inactiveCount(for: project)) off")
                        Spacer()
                        Button("Disable All") {
                            store.disableAll(in: project)
                        }
                        .disabled(store.activeCount(for: project) == 0)

                        Button("Add Project...") {
                            store.addProjects(ProjectOpenPanel.selectProjects())
                        }
                        .buttonStyle(.link)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 380, height: 500)
    }
}

private struct MenuSkillRow: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let onToggle: () -> Void
    let onTransfer: (SkillProject, SkillTransferMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(skill.isEnabled ? .green : .secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortText(skill.name, limit: 32))
                            .font(.callout)
                            .lineLimit(1)

                        if let summary = skill.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(skill.isEnabled ? "On" : "Off")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(skill.isEnabled ? .green : .secondary)
                        .frame(width: 28, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if destinationProjects.isEmpty {
                    Button("Add another project first") {}
                        .disabled(true)
                } else {
                    Menu("Copy To") {
                        ForEach(destinationProjects) { project in
                            Button(project.name) {
                                onTransfer(project, .copy)
                            }
                        }
                    }

                    Menu("Move To") {
                        ForEach(destinationProjects) { project in
                            Button(project.name) {
                                onTransfer(project, .move)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Copy or move skill")
        }
        .background(.quaternary.opacity(0.0001), in: RoundedRectangle(cornerRadius: 6))
    }
}
