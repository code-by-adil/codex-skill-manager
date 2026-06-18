import CodexSkillCore
import SwiftUI

struct SkillPackageSectionView: View {
    @ObservedObject var store: SkillStore
    let packages: [SkillPackage]
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let filter: SkillFilter
    let searchText: String
    let onManagePackage: (SkillPackage) -> Void
    let onEditPackage: (SkillPackage) -> Void
    let onChooseProjectDestination: (SkillPackage, SkillTransferMode) -> Void

    private var visiblePackages: [SkillPackage] {
        SkillPackageSearch.visiblePackages(
            packages,
            store: store,
            filter: filter,
            searchText: searchText
        )
    }

    var body: some View {
        if !visiblePackages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Packages", systemImage: "shippingbox")
                        .font(.headline)

                    Spacer()

                    Text("\(visiblePackages.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    ForEach(visiblePackages) { package in
                        SkillPackageRowView(
                            store: store,
                            package: package,
                            destinationProjects: destinationProjects,
                            globalDestinations: globalDestinations,
                            filter: filter,
                            searchText: searchText,
                            onManagePackage: onManagePackage,
                            onEditPackage: onEditPackage,
                            onChooseProjectDestination: onChooseProjectDestination
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct SkillPackageRowView: View {
    @ObservedObject var store: SkillStore
    let package: SkillPackage
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let filter: SkillFilter
    let searchText: String
    let onManagePackage: (SkillPackage) -> Void
    let onEditPackage: (SkillPackage) -> Void
    let onChooseProjectDestination: (SkillPackage, SkillTransferMode) -> Void

    @State private var isConfirmingDelete = false

    private var packageSkills: [SkillItem] {
        store.skills(in: package)
    }

    private var missingSkillNames: [String] {
        store.missingSkillNames(in: package)
    }

    private var enabledCount: Int {
        packageSkills.filter(\.isEnabled).count
    }

    private var disabledCount: Int {
        packageSkills.filter { !$0.isEnabled }.count
    }

    private var hasAvailableSkills: Bool {
        !packageSkills.isEmpty
    }

    private var matchSummary: String? {
        guard !searchText.isEmpty || filter != .all else {
            return nil
        }

        let matchingNames = SkillPackageSearch
            .matchingSkills(in: package, store: store, filter: filter, searchText: searchText)
            .map(\.name)

        let matchingMissingNames: [String]
        if filter == .all, !searchText.isEmpty {
            matchingMissingNames = missingSkillNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
        } else {
            matchingMissingNames = []
        }

        let names = matchingNames + matchingMissingNames
        guard !names.isEmpty else {
            return package.name.localizedCaseInsensitiveContains(searchText) ? "Package name match" : nil
        }

        let shownNames = names.prefix(3).joined(separator: ", ")
        let remainingCount = names.count - 3
        return remainingCount > 0 ? "Matches: \(shownNames), +\(remainingCount)" : "Matches: \(shownNames)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(package.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                Button("Manage") {
                    onManagePackage(package)
                }
                .controlSize(.small)

                Button("Enable All") {
                    store.enablePackage(package)
                }
                .controlSize(.small)
                .disabled(disabledCount == 0)

                Button("Disable All") {
                    store.disablePackage(package)
                }
                .controlSize(.small)
                .disabled(enabledCount == 0)

                Button("Edit") {
                    onEditPackage(package)
                }
                .controlSize(.small)

                PackageActionsMenu(
                    package: package,
                    hasAvailableSkills: hasAvailableSkills,
                    destinationProjects: destinationProjects,
                    globalDestinations: globalDestinations,
                    onChooseProjectDestination: onChooseProjectDestination,
                    onCopyToProject: { project in
                        store.transferPackage(package, to: project, mode: .copy)
                    },
                    onMoveToProject: { project in
                        store.transferPackage(package, to: project, mode: .move)
                    },
                    onCopyToGlobal: { location in
                        store.transferPackage(package, toGlobal: location, mode: .copy)
                    },
                    onMoveToGlobal: { location in
                        store.transferPackage(package, toGlobal: location, mode: .move)
                    },
                    onDelete: { isConfirmingDelete = true }
                )
            }

            if let matchSummary {
                Text(matchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 36)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Delete \(package.name)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Package", role: .destructive) {
                store.deletePackage(package)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes only the package grouping. The skill folders remain unchanged.")
        }
    }

    private var summary: String {
        var parts = ["\(package.skillNames.count) skills", "\(enabledCount) on", "\(disabledCount) off"]

        let missingCount = missingSkillNames.count
        if missingCount > 0 {
            parts.append("\(missingCount) missing")
        }

        return parts.joined(separator: " · ")
    }
}

@MainActor
enum SkillPackageSearch {
    static func visiblePackages(
        _ packages: [SkillPackage],
        store: SkillStore,
        filter: SkillFilter,
        searchText: String
    ) -> [SkillPackage] {
        packages.filter { package in
            packageMatches(package, store: store, filter: filter, searchText: searchText)
        }
    }

    static func matchingSkills(
        in package: SkillPackage,
        store: SkillStore,
        filter: SkillFilter,
        searchText: String
    ) -> [SkillItem] {
        store.skills(in: package).filter { skill in
            let passesFilter: Bool
            switch filter {
            case .all:
                passesFilter = true
            case .enabled:
                passesFilter = skill.isEnabled
            case .disabled:
                passesFilter = !skill.isEnabled
            }

            guard passesFilter else {
                return false
            }

            guard !searchText.isEmpty else {
                return true
            }

            return [skill.name, skill.summary ?? ""]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private static func packageMatches(
        _ package: SkillPackage,
        store: SkillStore,
        filter: SkillFilter,
        searchText: String
    ) -> Bool {
        let packageNameMatches = !searchText.isEmpty && package.name.localizedCaseInsensitiveContains(searchText)
        let missingSkillMatches = filter == .all
            && !searchText.isEmpty
            && store.missingSkillNames(in: package).contains { $0.localizedCaseInsensitiveContains(searchText) }

        guard !searchText.isEmpty || filter != .all else {
            return true
        }

        return packageNameMatches
            || missingSkillMatches
            || !matchingSkills(in: package, store: store, filter: filter, searchText: searchText).isEmpty
    }
}

struct PackageActionsMenu: View {
    let package: SkillPackage
    let hasAvailableSkills: Bool
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let onChooseProjectDestination: (SkillPackage, SkillTransferMode) -> Void
    let onCopyToProject: (SkillProject) -> Void
    let onMoveToProject: (SkillProject) -> Void
    let onCopyToGlobal: (GlobalSkillLocation) -> Void
    let onMoveToGlobal: (GlobalSkillLocation) -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            PackageDestinationSubmenu(
                title: "Copy To",
                systemImage: "doc.on.doc",
                destinationProjects: destinationProjects,
                globalDestinations: globalDestinations,
                onChooseDestination: { onChooseProjectDestination(package, .copy) },
                onSelectGlobal: onCopyToGlobal,
                onSelectProject: onCopyToProject
            )
            .disabled(!hasAvailableSkills)

            PackageDestinationSubmenu(
                title: "Move To",
                systemImage: "arrowshape.turn.up.right",
                destinationProjects: destinationProjects,
                globalDestinations: globalDestinations,
                onChooseDestination: { onChooseProjectDestination(package, .move) },
                onSelectGlobal: onMoveToGlobal,
                onSelectProject: onMoveToProject
            )
            .disabled(!hasAvailableSkills)

            Divider()

            Button("Delete Package", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("Package actions")
    }
}

struct PackageDestinationSubmenu: View {
    let title: String
    let systemImage: String
    let destinationProjects: [SkillProject]
    let globalDestinations: [GlobalSkillLocation]
    let onChooseDestination: () -> Void
    let onSelectGlobal: (GlobalSkillLocation) -> Void
    let onSelectProject: (SkillProject) -> Void

    var body: some View {
        Menu {
            if !destinationProjects.isEmpty {
                ForEach(destinationProjects) { project in
                    Button(project.name) {
                        onSelectProject(project)
                    }
                }
                Divider()
            }

            Button("Choose Project...") {
                onChooseDestination()
            }

            if !globalDestinations.isEmpty {
                Divider()

                ForEach(globalDestinations) { location in
                    Button(location.label) {
                        onSelectGlobal(location)
                    }
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}
