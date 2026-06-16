import XCTest
@testable import CodexSkillCore

final class SkillFileServiceTests: XCTestCase {
    private var temporaryRoot: URL!
    private var service: SkillFileService!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSkillCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        service = SkillFileService()
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("active-one").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.inactiveDirectory(for: project).appendingPathComponent("active-one").path))
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

    func testDisableAllPreflightsDestinationConflictsBeforeMoving() throws {
        let project = try makeProject(named: "Project")
        try makeSkill(named: "conflict", in: service.activeDirectory(for: project))
        try makeSkill(named: "conflict", in: service.inactiveDirectory(for: project))
        try makeSkill(named: "other", in: service.activeDirectory(for: project))

        XCTAssertThrowsError(try service.disableAll(in: project))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("conflict").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.activeDirectory(for: project).appendingPathComponent("other").path))
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
