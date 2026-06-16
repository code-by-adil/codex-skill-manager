import XCTest
@testable import CodexSkillCore

final class SkillFileServiceTests: XCTestCase {
    private var temporaryRoot: URL!
    private var service: SkillFileService!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSkillCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        service = SkillFileService(
            centralInactiveRootURL: temporaryRoot.appendingPathComponent("CentralInactive", isDirectory: true)
        )
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testScanReadsActiveAndInactiveSkills() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "active-one", in: service.activeDirectory(for: project))
        try makeSkill(named: "inactive-one", in: service.inactiveDirectory(for: project))

        let skills = try service.scan(project: project)

        XCTAssertEqual(skills.map(\.name), ["active-one", "inactive-one"])
        XCTAssertEqual(skills.first { $0.name == "active-one" }?.state, .active)
        XCTAssertEqual(skills.first { $0.name == "inactive-one" }?.state, .inactive)
        XCTAssertEqual(skills.first { $0.name == "active-one" }?.summary, "A test skill")
    }

    func testDisablingMovesSkillToInactiveDirectory() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "active-one", in: service.activeDirectory(for: project))
        let skill = try XCTUnwrap(try service.scan(project: project).first)

        let destination = try service.setEnabled(skill, enabled: false, in: project)

        XCTAssertEqual(destination.deletingLastPathComponent().lastPathComponent, SkillFileService.inactiveSkillsDirectoryName)
        XCTAssertFalse(destination.path.hasPrefix(project.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("active-one").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("active-one").path))
    }

    func testScanMigratesLegacyProjectInactiveSkillsToCentralStore() throws {
        let project = try makeProject(named: "Project")
        let legacyInactiveDirectory = project.url
            .appendingPathComponent(SkillFileService.agentsDirectoryName, isDirectory: true)
            .appendingPathComponent(SkillFileService.inactiveSkillsDirectoryName, isDirectory: true)
        try makeSkill(named: "legacy-disabled", in: legacyInactiveDirectory)

        let skills = try service.scan(project: project)

        XCTAssertEqual(skills.map(\.name), ["legacy-disabled"])
        XCTAssertEqual(skills.first?.state, .inactive)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyInactiveDirectory.appendingPathComponent("legacy-disabled").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("legacy-disabled").path))
    }

    func testCopyTransfersSkillToDestinationActiveDirectory() throws {
        let sourceProject = try makeProject(named: "Source")
        let destinationProject = try makeProject(named: "Destination")
        try makeSkill(named: "shared-skill", in: service.activeDirectory(for: sourceProject))
        let skill = try XCTUnwrap(try service.scan(project: sourceProject).first)

        let destination = try service.transfer(skill, to: destinationProject, mode: .copy)

        XCTAssertEqual(destination.path, service.activeDirectory(for: destinationProject).appendingPathComponent("shared-skill").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: sourceProject).appendingPathComponent("shared-skill").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testTransferCreatesDestinationProjectSkillDirectory() throws {
        let sourceProject = try makeProject(named: "Source")
        let destinationURL = temporaryRoot.appendingPathComponent("UnmanagedDestination", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let destinationProject = SkillProject(path: destinationURL.path)
        try makeSkill(named: "shared-skill", in: service.activeDirectory(for: sourceProject))
        let skill = try XCTUnwrap(try service.scan(project: sourceProject).first)

        let destination = try service.transfer(skill, to: destinationProject, mode: .copy)

        XCTAssertEqual(destination.path, service.activeDirectory(for: destinationProject).appendingPathComponent("shared-skill").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testScanUsesClaudeProjectDirectories() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "claude-skill", in: service.activeDirectory(for: project, provider: .claude))

        let codexSkills = try service.scan(project: project, provider: .codex)
        let claudeSkills = try service.scan(project: project, provider: .claude)

        XCTAssertTrue(codexSkills.isEmpty)
        XCTAssertEqual(claudeSkills.map(\.name), ["claude-skill"])
        XCTAssertEqual(claudeSkills.first?.provider, .claude)
    }

    func testTransferCanTargetClaudeSkillDirectory() throws {
        let sourceProject = try makeProject(named: "Source")
        let destinationProject = try makeProject(named: "Destination")
        try makeSkill(named: "shared-skill", in: service.activeDirectory(for: sourceProject, provider: .claude))
        let skill = try XCTUnwrap(try service.scan(project: sourceProject, provider: .claude).first)

        let destination = try service.transfer(skill, to: destinationProject, mode: .copy, provider: .claude)

        XCTAssertEqual(destination.path, service.activeDirectory(for: destinationProject, provider: .claude).appendingPathComponent("shared-skill").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testCopyCodexSkillsToClaudePreservesEnabledState() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "enabled-skill", in: service.activeDirectory(for: project, provider: .codex))
        try makeSkill(named: "disabled-skill", in: service.inactiveDirectory(for: project, provider: .codex))

        let result = try service.copyCodexSkillsToClaude(in: project)

        XCTAssertEqual(result.copiedEnabled, 1)
        XCTAssertEqual(result.copiedDisabled, 1)
        XCTAssertEqual(result.skippedExisting, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project, provider: .claude).appendingPathComponent("enabled-skill").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project, provider: .claude).appendingPathComponent("disabled-skill").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project, provider: .codex).appendingPathComponent("enabled-skill").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project, provider: .codex).appendingPathComponent("disabled-skill").path))
    }

    func testMoveTransfersSkillAndRemovesSource() throws {
        let sourceProject = try makeProject(named: "Source")
        let destinationProject = try makeProject(named: "Destination")
        try makeSkill(named: "shared-skill", in: service.inactiveDirectory(for: sourceProject))
        let skill = try XCTUnwrap(try service.scan(project: sourceProject).first)

        try service.transfer(skill, to: destinationProject, mode: .move)

        XCTAssertFalse(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: sourceProject).appendingPathComponent("shared-skill").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: destinationProject).appendingPathComponent("shared-skill").path))
    }

    func testDisableAllMovesActiveSkillsToInactiveDirectory() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "first", in: service.activeDirectory(for: project))
        try makeSkill(named: "second", in: service.activeDirectory(for: project))
        try makeSkill(named: "already-disabled", in: service.inactiveDirectory(for: project))

        let disabledCount = try service.disableAll(in: project)

        XCTAssertEqual(disabledCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("first").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("second").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("first").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("second").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("already-disabled").path))
    }

    func testEnableAllMovesInactiveSkillsToActiveDirectory() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "already-enabled", in: service.activeDirectory(for: project))
        try makeSkill(named: "first", in: service.inactiveDirectory(for: project))
        try makeSkill(named: "second", in: service.inactiveDirectory(for: project))

        let enabledCount = try service.enableAll(in: project)

        XCTAssertEqual(enabledCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("already-enabled").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("first").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("second").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("first").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("second").path))
    }

    func testDisableAllPreflightsDestinationConflictsBeforeMoving() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "conflict", in: service.activeDirectory(for: project))
        try makeSkill(named: "conflict", in: service.inactiveDirectory(for: project))
        try makeSkill(named: "other", in: service.activeDirectory(for: project))

        XCTAssertThrowsError(try service.disableAll(in: project))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("conflict").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("other").path))
    }

    func testEnableAllPreflightsDestinationConflictsBeforeMoving() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "conflict", in: service.activeDirectory(for: project))
        try makeSkill(named: "conflict", in: service.inactiveDirectory(for: project))
        try makeSkill(named: "other", in: service.inactiveDirectory(for: project))

        XCTAssertThrowsError(try service.enableAll(in: project))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("conflict").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("other").path))
    }

    private func makeProject(named name: String) throws -> SkillProject {
        let projectURL = temporaryRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let project = SkillProject(path: projectURL.path)
        try service.ensureProjectSkillDirectories(for: project)
        return project
    }

    private func makeSkill(named name: String, in directory: URL) throws {
        let skillURL = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: skillURL, withIntermediateDirectories: true)
        let skillFile = skillURL.appendingPathComponent("SKILL.md")
        try """
        ---
        name: \(name)
        description: A test skill
        ---

        # \(name)
        """.write(to: skillFile, atomically: true, encoding: .utf8)
    }
}
