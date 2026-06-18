# Codex Skill Manager

A macOS app for keeping Codex project, global Codex, and global agent skills organized into intentional active sets.

Codex loads project-level skills from `.agents/skills/`. When that folder gets large, every active skill adds noise to the agent context.

Use Codex Skill Manager to keep project and global skill folders focused, package related skills together, and move everything else into safe inactive storage.

## Install

Requirements:

- macOS 14 or newer
- Xcode Command Line Tools
- Swift 5.9 or newer

```bash
git clone https://github.com/code-by-adil/codex-skill-manager.git
cd codex-skill-manager
./script/install.sh
```

The install script builds the app and copies it to:

```text
~/Applications/CodexSkillManager.app
```

To install into `/Applications`:

```bash
./script/install.sh --system
```

GitHub releases may include a prebuilt app archive. If macOS blocks the downloaded app on first launch, right-click the app and choose Open.

## Why This Exists

Some projects collect dozens or hundreds of skills over time:

```text
my-project/
  .agents/
    skills/
      swiftui-patterns/
      cloudflare-workers/
      security-scan/
      performance-debugging/
      ...
```

Every active project skill is context Codex may need to consider. This app lets you treat `.agents/skills/` as the active working set instead of a permanent warehouse.

The default workflow is not to delete skills. The goal is to make Codex sharper by keeping the active set intentional, with permanent deletion available when you really want to remove a skill.

## Feature Overview

### Skill Sources

- Manage project Codex skills in `<project>/.agents/skills/`.
- Switch project views between Codex (`.agents`) and Claude (`.claude`) skill folders.
- Manage global Codex skills from `~/.codex/skills/`.
- Manage global agent skills from `~/.agents/skills/`.
- See active and inactive counts for every project and global source in the sidebar.

### Enable, Disable, and Search

- Enable or disable individual skills with one click.
- Disable all skills when you want a clean project context.
- Enable all skills when you want the full library back.
- Search skills by name or summary.
- Filter skills by All, Enabled, or Disabled.
- Keep disabled skills outside your git worktree in app-owned inactive storage.

### Skill Packages

- Create named packages from existing project or global skills.
- Use packages for task bundles, such as auth, security, deployment, or mobile debugging skill sets.
- Add a skill to an existing package from that skill's row.
- Edit packages later to add or remove skills.
- Enable or disable every skill in a package as one unit.
- Copy or move a whole package to another project or global skill source.
- Search results show package matches without duplicating packaged skills in the main list.
- Use the dedicated package management sheet to manage individual packaged skills without cluttering the main skill list.
- Remove a skill from a package without deleting the skill folder.
- Delete a package grouping without deleting the included skill folders.

### Copy, Move, and Delete

- Copy or move skills between Codex projects.
- Copy or move skills between global skill folders and project skill folders.
- Copy or move skills between Global Codex and Global Agents.
- Copy or move individual skills from inside a package while preserving package membership at the destination.
- Pick any destination project from Finder, even if it has not been added to the app yet.
- Delete project or global skills permanently after confirmation.
- Refuse to overwrite existing destination skill folders.

### App Experience

- Use the full window for detailed project, global, and package management.
- Use the menu bar panel for quick switching without opening the full window.
- Remove projects from the manager without deleting project files.
- Reveal active and inactive skill folders in Finder.
- Install locally from source or build a GitHub release archive.

## How It Works

Codex Skill Manager keeps the active skill directory exactly where Codex expects it:

```text
<project>/.agents/skills/
```

When you disable a skill, the app moves that skill out of the project and into a central inactive store:

```text
~/Library/Application Support/CodexSkillManager/InactiveSkills/codex/<project-key>/inactive-skills/
```

When you enable it again, the app moves it back to:

```text
<project>/.agents/skills/<skill-name>/
```

That means disabled skills do not sit inside your repository as renamed folders, hidden folders, or extra project-local directories. Your git status stays cleaner, and the active Codex context stays smaller.

Global skills are managed from a separate Global Skills section:

```text
~/.codex/skills/
~/.agents/skills/
```

When you disable a global skill, the app moves it into app-owned inactive storage:

```text
~/Library/Application Support/CodexSkillManager/InactiveSkills/global/codex/inactive-skills/
~/Library/Application Support/CodexSkillManager/InactiveSkills/global/agents/inactive-skills/
```

## Daily Workflow

1. Add a Codex project from the sidebar.
2. Review the skills in that project's `.agents/skills/` directory.
3. Disable anything you do not want Codex to load for day-to-day work.
4. Re-enable specialized skills when the task calls for them.
5. Copy or move useful skills into other projects as your library improves.

Use the Global Skills section for machine-wide Codex or agent skills that should be enabled or disabled outside a single project.

Use packages for task bundles that you commonly need together. For example, create an Auth package from email, session, security, and backend skills, then enable or move that package as one unit later. You can edit the package later, add a newly discovered skill from its row, or open the package manager to remove, move, copy, enable, disable, or delete individual packaged skills.

For large projects, a good starting point is to keep only the handful of skills you use every day enabled, then enable focused skills just before asking Codex to work in that domain.

## Safety Model

Codex Skill Manager is intentionally conservative:

- It manages project-level skills and supported global skill folders only.
- It does not manage arbitrary folders outside configured project and global skill locations.
- It does not edit skill contents.
- It can permanently delete a skill only after explicit confirmation.
- It refuses to overwrite an existing skill at the destination.
- It creates missing skill folders only when needed.
- Deleting a package removes only the grouping. It does not delete the included skill folders.
- It stores disabled skills in Application Support, outside the project worktree.
- Removing a project from the app removes it only from the app list. It does not delete the project or its skills.

If an older version of the app or a manual workflow left disabled skills in a project-local inactive folder, the app migrates those disabled skills to the central inactive store during scanning.

## Development

Clone the repository:

```bash
git clone https://github.com/code-by-adil/codex-skill-manager.git
cd codex-skill-manager
```

Run tests:

```bash
swift test
```

Build without launching:

```bash
swift build
```

Build, stage, and launch the app:

```bash
./script/build_and_run.sh
```

Verify app launch:

```bash
./script/build_and_run.sh --verify
```

Create a release archive:

```bash
./script/package_release.sh
```

The app is a SwiftPM macOS app. There is no Xcode project required for normal development.

## Project Structure

```text
Sources/
  CodexSkillCore/        File operations, models, and tests
  CodexSkillManager/     SwiftUI app, menu bar UI, and project store
Tests/
  CodexSkillCoreTests/   Filesystem behavior tests
script/
  build_and_run.sh       Local build, bundle, launch, and verification script
  install.sh             Build and install to Applications
  package_release.sh     Create a release archive
  stage_app.sh           Stage the SwiftPM executable as a macOS app bundle
docs/
  RELEASE.md             Release and packaging checklist
```

## Contributing

Issues and pull requests are welcome. The best contributions make Codex skill management more reliable, more legible, or faster without expanding the app beyond its core job: helping users keep Codex project context clean.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a larger change.

## License

MIT. See [LICENSE](LICENSE).
