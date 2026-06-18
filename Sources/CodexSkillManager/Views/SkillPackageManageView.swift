import CodexSkillCore
import SwiftUI

struct SkillPackageManageView: View {
    @ObservedObject var store: SkillStore
    let package: SkillPackage
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let onEditPackage: (SkillPackage) -> Void
    let onClose: () -> Void

    @State private var filter: SkillFilter = .all
    @State private var searchText = ""
    @State private var skillPendingDelete: SkillItem?

    private var currentPackage: SkillPackage {
        store.packages.first { $0.id == package.id } ?? package
    }

    private var packageSkills: [SkillItem] {
        store.skills(in: currentPackage)
    }

    private var missingSkillNames: [String] {
        store.missingSkillNames(in: currentPackage)
    }

    private var visibleSkills: [SkillItem] {
        packageSkills
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

                return [skill.name, skill.summary ?? ""]
                    .joined(separator: " ")
                    .localizedCaseInsensitiveContains(searchText)
            }
    }

    private var visibleMissingSkillNames: [String] {
        guard filter == .all else {
            return []
        }

        guard !searchText.isEmpty else {
            return missingSkillNames
        }

        return missingSkillNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var enabledCount: Int {
        packageSkills.filter(\.isEnabled).count
    }

    private var disabledCount: Int {
        packageSkills.filter { !$0.isEnabled }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(SkillFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField("Search package skills", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            if visibleSkills.isEmpty && visibleMissingSkillNames.isEmpty {
                ContentUnavailableView {
                    Label("No Package Skills", systemImage: "shippingbox")
                } description: {
                    Text("No skills in this package match the current view.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                packageSkillList
            }

            Divider()

            HStack {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Edit Package") {
                    onEditPackage(currentPackage)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 760, minHeight: 620)
        .confirmationDialog(
            "Delete \(skillPendingDelete?.name ?? "Skill")?",
            isPresented: Binding(
                get: { skillPendingDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        skillPendingDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let skill = skillPendingDelete {
                    store.delete(skill, from: currentPackage)
                }
                skillPendingDelete = nil
            }

            Button("Cancel", role: .cancel) {
                skillPendingDelete = nil
            }
        } message: {
            Text("This deletes the skill folder immediately and removes it from this package. It cannot be restored from Codex Skill Manager.")
        }
    }

    private var packageSkillList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                PackageManageListHeader()

                ForEach(visibleSkills) { skill in
                    PackageManageSkillRow(
                        store: store,
                        skill: skill,
                        package: currentPackage,
                        destinationProjects: destinationProjects,
                        globalDestinations: globalDestinations,
                        onDelete: {
                            skillPendingDelete = skill
                        }
                    )
                }

                ForEach(visibleMissingSkillNames, id: \.self) { skillName in
                    PackageManageMissingSkillRow(skillName: skillName) {
                        store.remove(skillNamed: skillName, from: currentPackage)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.background)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.secondary)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(currentPackage.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Button("Enable All") {
                store.enablePackage(currentPackage)
            }
            .controlSize(.small)
            .disabled(disabledCount == 0)

            Button("Disable All") {
                store.disablePackage(currentPackage)
            }
            .controlSize(.small)
            .disabled(enabledCount == 0)
        }
        .padding()
    }

    private var summary: String {
        var parts = ["\(currentPackage.skillNames.count) skills", "\(enabledCount) on", "\(disabledCount) off"]

        let missingCount = missingSkillNames.count
        if missingCount > 0 {
            parts.append("\(missingCount) missing")
        }

        return parts.joined(separator: " · ")
    }
}

private struct PackageManageListHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Skill")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("State")
                .frame(width: 84, alignment: .center)

            Text("Actions")
                .frame(width: 112, alignment: .trailing)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .padding(.trailing, 12)
    }
}

private struct PackageManageSkillRow: View {
    @ObservedObject var store: SkillStore
    let skill: SkillItem
    let package: SkillPackage
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.toggle(skill, in: package)
            } label: {
                Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skill.isEnabled ? .green : .secondary)
                    .font(.title3)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(skill.isEnabled ? "Disable skill" : "Enable skill")

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.headline)
                    .lineLimit(1)

                if let summary = skill.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .layoutPriority(1)

            Text(skill.state.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(skill.isEnabled ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .frame(width: 84)

            PackageManageSkillActionsMenu(
                skill: skill,
                destinationProjects: destinationProjects,
                globalDestinations: globalDestinations,
                onToggle: {
                    store.toggle(skill, in: package)
                },
                onChooseProjectDestination: { mode in
                    if let destinationURL = ProjectOpenPanel.selectTransferDestination() {
                        store.transfer(skill, in: package, toProjectAt: destinationURL, mode: mode)
                    }
                },
                onCopyToProject: { project in
                    store.transfer(skill, in: package, to: project, mode: .copy)
                },
                onMoveToProject: { project in
                    store.transfer(skill, in: package, to: project, mode: .move)
                },
                onCopyToGlobal: { location in
                    store.transfer(skill, in: package, toGlobal: location, mode: .copy)
                },
                onMoveToGlobal: { location in
                    store.transfer(skill, in: package, toGlobal: location, mode: .move)
                },
                onRemoveFromPackage: {
                    store.remove(skill, from: package)
                },
                onDelete: onDelete
            )
            .frame(width: 112, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .padding(.trailing, 12)
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct PackageManageMissingSkillRow: View {
    let skillName: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(skillName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Missing from disk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Missing")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .frame(width: 84)

            Button {
                onRemove()
            } label: {
                Label("Remove", systemImage: "xmark.circle")
            }
            .controlSize(.small)
            .help("Remove missing skill from package")
            .frame(width: 112, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .padding(.trailing, 12)
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct PackageManageSkillActionsMenu: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let onToggle: () -> Void
    let onChooseProjectDestination: (SkillTransferMode) -> Void
    let onCopyToProject: (SkillProject) -> Void
    let onMoveToProject: (SkillProject) -> Void
    let onCopyToGlobal: (GlobalSkillLocation) -> Void
    let onMoveToGlobal: (GlobalSkillLocation) -> Void
    let onRemoveFromPackage: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(
                skill.isEnabled ? "Disable Skill" : "Enable Skill",
                systemImage: skill.isEnabled ? "circle" : "checkmark.circle",
                action: onToggle
            )

            Divider()

            PackageDestinationSubmenu(
                title: "Copy To",
                systemImage: "doc.on.doc",
                destinationProjects: destinationProjects,
                globalDestinations: globalDestinations,
                onChooseDestination: { onChooseProjectDestination(.copy) },
                onSelectGlobal: onCopyToGlobal,
                onSelectProject: onCopyToProject
            )

            PackageDestinationSubmenu(
                title: "Move To",
                systemImage: "arrowshape.turn.up.right",
                destinationProjects: destinationProjects,
                globalDestinations: globalDestinations,
                onChooseDestination: { onChooseProjectDestination(.move) },
                onSelectGlobal: onMoveToGlobal,
                onSelectProject: onMoveToProject
            )

            Divider()

            Button("Remove from Package", systemImage: "xmark.circle", action: onRemoveFromPackage)
            Button("Delete Permanently", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .menuStyle(.button)
        .controlSize(.small)
        .fixedSize()
        .help("Skill actions")
    }
}
