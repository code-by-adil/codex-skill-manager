import CodexSkillCore
import SwiftUI

struct GlobalSkillDetailView: View {
    @ObservedObject var store: SkillStore
    let location: GlobalSkillLocation

    @State private var filter: SkillFilter = .all
    @State private var searchText = ""
    @State private var isCreatingPackage = false
    @State private var packageBeingEdited: SkillPackage?
    @State private var packageBeingManaged: SkillPackage?

    private var visibleSkills: [SkillItem] {
        store.globalSkills(for: location)
            .filter { !packagedSkillNames.contains($0.name) }
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

    private var otherGlobalLocations: [GlobalSkillLocation] {
        GlobalSkillLocation.allCases.filter { $0 != location }
    }

    private var packages: [SkillPackage] {
        store.packages(for: location)
    }

    private var visiblePackages: [SkillPackage] {
        SkillPackageSearch.visiblePackages(
            packages,
            store: store,
            filter: filter,
            searchText: searchText
        )
    }

    private var packagedSkillNames: Set<String> {
        Set(packages.flatMap(\.skillNames))
    }

    var body: some View {
        VStack(spacing: 0) {
            GlobalSkillHeaderView(
                store: store,
                location: location,
                onCreatePackage: { isCreatingPackage = true }
            )

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

            if let globalError = store.globalErrors[location.id] {
                Label(globalError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if !visiblePackages.isEmpty {
                SkillPackageSectionView(
                    store: store,
                    packages: packages,
                    destinationProjects: store.projects,
                    globalDestinations: otherGlobalLocations,
                    filter: filter,
                    searchText: searchText,
                    onManagePackage: { package in
                        packageBeingManaged = package
                    },
                    onEditPackage: { package in
                        packageBeingEdited = package
                    },
                    onChooseProjectDestination: { package, mode in
                        if let destinationURL = ProjectOpenPanel.selectTransferDestination() {
                            store.transferPackage(package, toProjectAt: destinationURL, mode: mode)
                        }
                    }
                )

                Divider()
            }

            if visibleSkills.isEmpty && visiblePackages.isEmpty {
                ContentUnavailableView {
                    Label("No Skills", systemImage: "wand.and.stars.inverse")
                } description: {
                    Text("No global skills match the current view.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !visibleSkills.isEmpty {
                List(visibleSkills) { skill in
                    SkillRowView(
                        skill: skill,
                        destinationProjects: store.projects,
                        globalDestinations: otherGlobalLocations,
                        packages: packages,
                        onToggle: { store.toggleGlobal(skill, in: location) },
                        onTransfer: { destinationProject, mode in
                            store.transferGlobal(skill, to: destinationProject, mode: mode)
                        },
                        onChooseDestination: { mode in
                            if let destinationURL = ProjectOpenPanel.selectTransferDestination() {
                                store.transferGlobal(skill, toProjectAt: destinationURL, mode: mode)
                            }
                        },
                        onTransferToGlobal: { destinationLocation, mode in
                            store.transfer(skill, toGlobal: destinationLocation, mode: mode)
                        },
                        onAddToPackage: { package in
                            store.add(skill, to: package)
                        },
                        onDelete: {
                            store.delete(skill)
                        }
                    )
                }
                .listStyle(.inset)
            } else {
                Spacer(minLength: 0)
            }
        }
        .navigationTitle(location.label)
        .sheet(isPresented: $isCreatingPackage) {
            SkillPackageEditorView(
                title: "New Package",
                skills: store.globalSkills(for: location),
                onCancel: { isCreatingPackage = false },
                onSave: { name, skillNames in
                    store.createPackage(named: name, skillNames: skillNames, for: location)
                    isCreatingPackage = false
                }
            )
        }
        .sheet(item: $packageBeingEdited) { package in
            SkillPackageEditorView(
                title: "Edit Package",
                skills: store.globalSkills(for: location),
                initialName: package.name,
                initialSkillNames: Set(package.skillNames),
                actionTitle: "Save Package",
                onCancel: { packageBeingEdited = nil },
                onSave: { name, skillNames in
                    store.updatePackage(package, name: name, skillNames: skillNames)
                    packageBeingEdited = nil
                }
            )
        }
        .sheet(item: $packageBeingManaged) { package in
            SkillPackageManageView(
                store: store,
                package: package,
                destinationProjects: store.projects,
                globalDestinations: otherGlobalLocations,
                onEditPackage: { package in
                    packageBeingManaged = nil
                    DispatchQueue.main.async {
                        packageBeingEdited = package
                    }
                },
                onClose: {
                    packageBeingManaged = nil
                }
            )
        }
    }
}

private struct GlobalSkillHeaderView: View {
    @ObservedObject var store: SkillStore
    let location: GlobalSkillLocation
    let onCreatePackage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(location.label)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)

                    Text(activePathDisplay)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    CountBadge(title: "Enabled", count: store.activeCount(for: location), color: .green)
                    CountBadge(title: "Disabled", count: store.inactiveCount(for: location), color: .secondary)
                }
            }

            HStack(spacing: 10) {
                Spacer(minLength: 12)

                HeaderActionButton(
                    title: "New Package",
                    systemImage: "shippingbox",
                    help: "Create a package from this source's skills"
                ) {
                    onCreatePackage()
                }

                if store.activeCount(for: location) > 0 {
                    HeaderActionButton(
                        title: "Disable All",
                        systemImage: "archivebox.fill",
                        help: "Move all enabled global skills to inactive skills"
                    ) {
                        store.disableAllGlobal(in: location)
                    }
                } else {
                    HeaderActionButton(
                        title: "Enable All",
                        systemImage: "checkmark.circle.fill",
                        help: "Move all disabled global skills back to active skills",
                        isDisabled: store.inactiveCount(for: location) == 0
                    ) {
                        store.enableAllGlobal(in: location)
                    }
                }

                Menu {
                    Button("Enabled Skills Folder") {
                        store.revealGlobalDirectory(for: location, state: .active)
                    }

                    Button("Disabled Skills Folder") {
                        store.revealGlobalDirectory(for: location, state: .inactive)
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

    private var activePathDisplay: String {
        "~/\(location.configurationDirectoryName)/\(SkillFileService.activeSkillsDirectoryName)"
    }
}
