import CodexSkillCore
import SwiftUI

struct SkillRowView: View {
    let skill: SkillItem
    let destinationProjects: [SkillProject]
    let onToggle: () -> Void
    let onTransfer: (SkillProject, SkillTransferMode) -> Void

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
                disabledHelp: "Add another project before copying skills",
                destinationProjects: destinationProjects
            ) { destinationProject in
                onTransfer(destinationProject, .copy)
            }

            TransferDestinationMenu(
                title: "Move",
                systemImage: "arrowshape.turn.up.right",
                disabledHelp: "Add another project before moving skills",
                destinationProjects: destinationProjects
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
    let disabledHelp: String
    let destinationProjects: [SkillProject]
    let onSelect: (SkillProject) -> Void

    var body: some View {
        if destinationProjects.isEmpty {
            Button {} label: {
                Label(title, systemImage: systemImage)
            }
            .controlSize(.small)
            .disabled(true)
            .help(disabledHelp)
        } else {
            Menu {
                ForEach(destinationProjects) { project in
                    Button(project.name) {
                        onSelect(project)
                    }
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
            .menuStyle(.button)
            .controlSize(.small)
            .help("\(title) to another project")
        }
    }
}
