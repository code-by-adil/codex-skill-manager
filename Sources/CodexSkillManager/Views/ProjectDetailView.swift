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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text(project.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            CountBadge(title: "Enabled", count: store.activeCount(for: project), color: .green)
            CountBadge(title: "Disabled", count: store.inactiveCount(for: project), color: .secondary)

            Button {
                store.disableAll(in: project)
            } label: {
                Label("Disable All", systemImage: "archivebox.fill")
            }
            .disabled(store.activeCount(for: project) == 0)
            .help("Move all enabled skills to inactive skills")

            Button {
                store.revealDirectory(for: project, state: .active)
            } label: {
                Label("Enabled", systemImage: "folder")
            }
            .help("Reveal enabled skills")

            Button {
                store.revealDirectory(for: project, state: .inactive)
            } label: {
                Label("Disabled", systemImage: "archivebox")
            }
            .help("Reveal disabled skills")
        }
        .padding()
    }
}

private struct CountBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 74)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.35), lineWidth: 1)
        }
    }
}
