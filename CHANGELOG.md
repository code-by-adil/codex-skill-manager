# Changelog

All notable changes to this project will be documented in this file.

This project follows a lightweight changelog format inspired by Keep a Changelog.

## [0.1.0] - 2026-06-18

### Added

- Menu bar and full-window management for project-level Codex skills.
- Global Codex skill management for `~/.codex/skills/`.
- Global Agents skill management for `~/.agents/skills/`.
- One-click enable and disable for individual skills.
- Disable All and Enable All actions for bulk context cleanup.
- Search and enabled/disabled filters.
- Copy and move actions for reusing skills across projects.
- Copy and move actions between project, global Codex, and global Agents skill sources.
- Finder-based destination picker for projects that are not saved in the app.
- Permanent skill deletion with confirmation.
- Skill packages for bundling related skills together.
- Package enable, disable, copy, move, edit, delete, and search support.
- Dedicated package management sheet for individual packaged skill actions.
- Package-aware search that avoids duplicating packaged skills in the main list.
- Central inactive skill storage under Application Support, grouped by project.
- Central inactive skill storage for global Codex and global Agents skills.
- Project removal confirmation that does not delete files on disk.
- Local SwiftPM build, bundle, launch, and verification script.
- Local install script for source-built app installs.
- Release packaging script with SHA-256 checksums.
- GitHub release workflow for tagged macOS archives.

### Changed

- Disabled skills are stored outside the project worktree to reduce git noise.
- Legacy project-local inactive skill folders are migrated into central storage when scanned.

### Security

- Skill transfers refuse to overwrite an existing destination skill directory.
