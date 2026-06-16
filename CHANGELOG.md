# Changelog

All notable changes to this project will be documented in this file.

This project follows a lightweight changelog format inspired by Keep a Changelog.

## [Unreleased]

### Added

- Menu bar and full-window management for project-level Codex skills.
- One-click enable and disable for individual skills.
- Disable All and Enable All actions for bulk context cleanup.
- Search and enabled/disabled filters.
- Copy and move actions for reusing skills across projects.
- Finder-based destination picker for projects that are not saved in the app.
- Central inactive skill storage under Application Support, grouped by project.
- Project removal confirmation that does not delete files on disk.
- Local SwiftPM build, bundle, launch, and verification script.

### Changed

- Disabled skills are stored outside the project worktree to reduce git noise.
- Legacy project-local inactive skill folders are migrated into central storage when scanned.

### Security

- Skill transfers refuse to overwrite an existing destination skill directory.
