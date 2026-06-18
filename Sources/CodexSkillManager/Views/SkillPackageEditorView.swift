import CodexSkillCore
import SwiftUI

struct SkillPackageEditorView: View {
    let title: String
    let skills: [SkillItem]
    let initialName: String
    let initialSkillNames: Set<String>
    let actionTitle: String
    let onCancel: () -> Void
    let onSave: (String, Set<String>) -> Void

    @State private var packageName = ""
    @State private var searchText = ""
    @State private var selectedSkillNames = Set<String>()

    init(
        title: String,
        skills: [SkillItem],
        initialName: String = "",
        initialSkillNames: Set<String> = [],
        actionTitle: String = "Create Package",
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Set<String>) -> Void
    ) {
        self.title = title
        self.skills = skills
        self.initialName = initialName
        self.initialSkillNames = initialSkillNames
        self.actionTitle = actionTitle
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private var uniqueSkills: [SkillItem] {
        var skillsByName: [String: SkillItem] = [:]

        for skill in skills {
            if let existing = skillsByName[skill.name], existing.isEnabled {
                continue
            }
            skillsByName[skill.name] = skill
        }

        return skillsByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var visibleSkills: [SkillItem] {
        guard !searchText.isEmpty else {
            return uniqueSkills
        }

        return uniqueSkills.filter { skill in
            [skill.name, skill.summary ?? ""]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var canCreate: Bool {
        !packageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedSkillNames.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text("\(selectedSkillNames.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()

            VStack(spacing: 10) {
                TextField("Package name", text: $packageName)
                    .textFieldStyle(.roundedBorder)

                TextField("Search skills", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            if uniqueSkills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills", systemImage: "shippingbox")
                } description: {
                    Text("There are no skills available to package in this source.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleSkills, id: \.name) { skill in
                    Toggle(isOn: selectionBinding(for: skill.name)) {
                        VStack(alignment: .leading, spacing: 3) {
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
                    }
                    .toggleStyle(.checkbox)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(actionTitle) {
                    onSave(packageName, selectedSkillNames)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            packageName = initialName
            selectedSkillNames = initialSkillNames
        }
    }

    private func selectionBinding(for skillName: String) -> Binding<Bool> {
        Binding(
            get: { selectedSkillNames.contains(skillName) },
            set: { isSelected in
                if isSelected {
                    selectedSkillNames.insert(skillName)
                } else {
                    selectedSkillNames.remove(skillName)
                }
            }
        )
    }
}
