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
                Label("\(store.provider.label) Skills", systemImage: "wand.and.stars")
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

                Picker("Mode", selection: Binding(get: {
                    store.provider
                }, set: { provider in
                    store.selectProvider(provider)
                })) {
                    ForEach(SkillProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

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
                                    },
                                    onChooseDestination: { mode in
                                        if let destinationURL = ProjectOpenPanel.selectTransferDestination() {
                                            store.transfer(skill, toProjectAt: destinationURL, mode: mode)
                                        }
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
                        if store.activeCount(for: project) > 0 {
                            Button("Disable All") {
                                store.disableAll(in: project)
                            }
                        } else {
                            Button("Enable All") {
                                store.enableAll(in: project)
                            }
                            .disabled(store.inactiveCount(for: project) == 0)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack {
                        Button("Convert to Claude") {
                            store.copyCodexSkillsToClaude(in: project)
                        }
                        .buttonStyle(.link)

                        Spacer()

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
        .alert(
            "Skill operation failed",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "Done",
            isPresented: Binding(
                get: { store.statusMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.statusMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                store.statusMessage = nil
            }
        } message: {
            Text(store.statusMessage ?? "")
        }
    }
}

private struct MenuSkillRow: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let onToggle: () -> Void
    let onTransfer: (SkillProject, SkillTransferMode) -> Void
    let onChooseDestination: (SkillTransferMode) -> Void

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
                Menu("Copy To") {
                    if !destinationProjects.isEmpty {
                        ForEach(destinationProjects) { project in
                            Button(project.name) {
                                onTransfer(project, .copy)
                            }
                        }
                        Divider()
                    }

                    Button("Choose Project...") {
                        onChooseDestination(.copy)
                    }
                }

                Menu("Move To") {
                    if !destinationProjects.isEmpty {
                        ForEach(destinationProjects) { project in
                            Button(project.name) {
                                onTransfer(project, .move)
                            }
                        }
                        Divider()
                    }

                    Button("Choose Project...") {
                        onChooseDestination(.move)
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
