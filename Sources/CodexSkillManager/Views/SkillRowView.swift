import CodexSkillCore
import SwiftUI

struct SkillRowView: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let showsTransferActions: Bool
    let globalDestinations: [GlobalSkillLocation]
    let packages: [SkillPackage]
    let onToggle: () -> Void
    let onTransfer: (SkillProject, SkillTransferMode) -> Void
    let onChooseDestination: (SkillTransferMode) -> Void
    let onTransferToGlobal: (GlobalSkillLocation, SkillTransferMode) -> Void
    let onAddToPackage: (SkillPackage) -> Void
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    init(
        skill: SkillItem,
        destinationProjects: [SkillProject],
        showsTransferActions: Bool = true,
        globalDestinations: [GlobalSkillLocation] = [],
        packages: [SkillPackage] = [],
        onToggle: @escaping () -> Void,
        onTransfer: @escaping (SkillProject, SkillTransferMode) -> Void,
        onChooseDestination: @escaping (SkillTransferMode) -> Void,
        onTransferToGlobal: @escaping (GlobalSkillLocation, SkillTransferMode) -> Void = { _, _ in },
        onAddToPackage: @escaping (SkillPackage) -> Void = { _ in },
        onDelete: @escaping () -> Void
    ) {
        self.skill = skill
        self.destinationProjects = destinationProjects
        self.showsTransferActions = showsTransferActions
        self.globalDestinations = globalDestinations
        self.packages = packages
        self.onToggle = onToggle
        self.onTransfer = onTransfer
        self.onChooseDestination = onChooseDestination
        self.onTransferToGlobal = onTransferToGlobal
        self.onAddToPackage = onAddToPackage
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
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

            Spacer(minLength: 12)

            Text(skill.state.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(skill.isEnabled ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            if showsTransferActions {
                TransferDestinationMenu(
                    title: "Copy",
                    systemImage: "doc.on.doc",
                    destinationProjects: destinationProjects,
                    globalDestinations: globalDestinations,
                    mode: .copy,
                    onChooseDestination: onChooseDestination,
                    onSelectGlobal: onTransferToGlobal
                ) { destinationProject in
                    onTransfer(destinationProject, .copy)
                }

                TransferDestinationMenu(
                    title: "Move",
                    systemImage: "arrowshape.turn.up.right",
                    destinationProjects: destinationProjects,
                    globalDestinations: globalDestinations,
                    mode: .move,
                    onChooseDestination: onChooseDestination,
                    onSelectGlobal: onTransferToGlobal
                ) { destinationProject in
                    onTransfer(destinationProject, .move)
                }
            }

            if !packages.isEmpty {
                SkillPackageAssignmentMenu(
                    packages: packages,
                    skillName: skill.name,
                    onSelect: onAddToPackage
                )
            }

            Button(skill.isEnabled ? "Disable" : "Enable", action: onToggle)
                .controlSize(.small)
                .frame(width: 74)

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Delete skill permanently")
        }
        .padding(.vertical, 6)
        .confirmationDialog(
            "Delete \(skill.name)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                onDelete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the skill folder immediately. It cannot be restored from Codex Skill Manager.")
        }
    }
}

struct SkillPackageAssignmentMenu: View {
    let packages: [SkillPackage]
    let skillName: String
    let onSelect: (SkillPackage) -> Void

    var body: some View {
        Menu {
            ForEach(packages) { package in
                Button {
                    onSelect(package)
                } label: {
                    if package.skillNames.contains(skillName) {
                        Label(package.name, systemImage: "checkmark")
                    } else {
                        Text(package.name)
                    }
                }
                .disabled(package.skillNames.contains(skillName))
            }
        } label: {
            Label("Package", systemImage: "shippingbox")
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("Add to package")
    }
}

struct TransferDestinationMenu: View {
    let title: String
    let systemImage: String
    let destinationProjects: [SkillProject]
    var globalDestinations: [GlobalSkillLocation] = []
    let mode: SkillTransferMode
    let onChooseDestination: (SkillTransferMode) -> Void
    var onSelectGlobal: (GlobalSkillLocation, SkillTransferMode) -> Void = { _, _ in }
    let onSelect: (SkillProject) -> Void

    var body: some View {
        Menu {
            if !destinationProjects.isEmpty {
                ForEach(destinationProjects) { project in
                    Button(project.name) {
                        onSelect(project)
                    }
                }
                Divider()
            }

            Button("Choose Project...") {
                onChooseDestination(mode)
            }

            if !globalDestinations.isEmpty {
                Divider()

                ForEach(globalDestinations) { location in
                    Button(location.label) {
                        onSelectGlobal(location, mode)
                    }
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("\(title) to a project or global skills")
    }
}
