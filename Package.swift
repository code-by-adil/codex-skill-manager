// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexSkillManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexSkillManager", targets: ["CodexSkillManager"]),
        .library(name: "CodexSkillCore", targets: ["CodexSkillCore"])
    ],
    targets: [
        .target(name: "CodexSkillCore"),
        .executableTarget(
            name: "CodexSkillManager",
            dependencies: ["CodexSkillCore"]
        ),
        .testTarget(
            name: "CodexSkillCoreTests",
            dependencies: ["CodexSkillCore"]
        )
    ]
)
