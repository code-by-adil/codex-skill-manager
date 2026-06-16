# Codex Skill Manager

A small macOS menu bar app for keeping Codex project skills powerful, focused, and easy to switch.

Codex discovers project-level skills from `.agents/skills/`. That is convenient until a project grows a large skill library. Keeping every possible skill active can pollute the context window, make tool selection noisier, and leave the agent carrying instructions it does not need for the task in front of it.

Codex Skill Manager gives you a simple control panel for that problem: keep a full skill library nearby, but only expose the skills you want Codex to see right now.

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

The goal is not to delete skills. The goal is to make Codex sharper by keeping the active set intentional.

## Features

- Enable or disable project-level Codex skills with one click.
- Use the menu bar panel for quick switching without opening a full window.
- Search and filter skills by enabled, disabled, or all.
- Disable all skills when you want a clean project context.
- Enable all skills when you want the full library back.
- Copy or move skills between Codex projects.
- Pick any destination project from Finder, even if it has not been added to the app yet.
- Keep disabled skills outside your git worktree in app-owned storage.
- Remove projects from the manager without deleting project files.
- Preview active and inactive skill counts per project.
- Optional Claude mode can mirror Codex skills into that project's agent skill folder.

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

## Install From Source

Codex Skill Manager is currently distributed as source.

Requirements:

- macOS 14 or newer
- Xcode Command Line Tools
- Swift 5.9 or newer

Build and run:

```bash
git clone <repository-url>
cd CodexSkillManager
swift test
./script/build_and_run.sh
```

The script builds the SwiftPM app, stages a local app bundle, and launches it:

```text
dist/CodexSkillManager.app
```

To verify the launch from the command line:

```bash
./script/build_and_run.sh --verify
```

## Daily Workflow

1. Add a Codex project from the sidebar.
2. Review the skills in that project's `.agents/skills/` directory.
3. Disable anything you do not want Codex to load for day-to-day work.
4. Re-enable specialized skills when the task calls for them.
5. Copy or move useful skills into other projects as your library improves.

For large projects, a good starting point is to keep only the handful of skills you use every day enabled, then enable focused skills just before asking Codex to work in that domain.

## Safety Model

Codex Skill Manager is intentionally conservative:

- It manages project-level skills only.
- It does not manage global Codex skills.
- It does not edit skill contents.
- It refuses to overwrite an existing skill at the destination.
- It creates missing skill folders only when needed.
- It stores disabled skills in Application Support, outside the project worktree.
- Removing a project from the app removes it only from the app list. It does not delete the project or its skills.

If an older version of the app or a manual workflow left disabled skills in a project-local inactive folder, the app migrates those disabled skills to the central inactive store during scanning.

## Project Structure

```text
Sources/
  CodexSkillCore/        File operations, models, and tests
  CodexSkillManager/     SwiftUI app, menu bar UI, and project store
Tests/
  CodexSkillCoreTests/   Filesystem behavior tests
script/
  build_and_run.sh       Local build, bundle, launch, and verification script
docs/
  RELEASE.md             Release and packaging checklist
```

## Development

Run tests:

```bash
swift test
```

Build without launching:

```bash
swift build
```

Build, stage, and launch the macOS app:

```bash
./script/build_and_run.sh
```

The app is a SwiftPM macOS app. There is no Xcode project required for normal development.

## Release Status

This project is ready for source-based open-source use. Signed and notarized binary distribution can be added by maintainers using the checklist in [docs/RELEASE.md](docs/RELEASE.md).

## Contributing

Issues and pull requests are welcome. The best contributions make Codex skill management more reliable, more legible, or faster without expanding the app beyond its core job: helping users keep Codex project context clean.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a larger change.

## License

MIT. See [LICENSE](LICENSE).
