import CodexSkillCore
import SwiftUI

struct SkillRowView: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let onToggle: () -> Void
    let onTransfer: (SkillProject, SkillTransferMode) -> Void
    let onChooseDestination: (SkillTransferMode) -> Void

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

            TransferDestinationMenu(
                title: "Copy",
                systemImage: "doc.on.doc",
                destinationProjects: destinationProjects,
                mode: .copy,
                onChooseDestination: onChooseDestination
            ) { destinationProject in
                onTransfer(destinationProject, .copy)
            }

            TransferDestinationMenu(
                title: "Move",
                systemImage: "arrowshape.turn.up.right",
                destinationProjects: destinationProjects,
                mode: .move,
                onChooseDestination: onChooseDestination
            ) { destinationProject in
                onTransfer(destinationProject, .move)
            }

            Button(skill.isEnabled ? "Disable" : "Enable", action: onToggle)
                .controlSize(.small)
                .frame(width: 74)
        }
        .padding(.vertical, 6)
    }
}

struct TransferDestinationMenu: View {
    let title: String
    let systemImage: String
    let destinationProjects: [SkillProject]
    let mode: SkillTransferMode
    let onChooseDestination: (SkillTransferMode) -> Void
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
        } label: {
            Label(title, systemImage: systemImage)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("\(title) to a saved or selected project")
    }
}
