# Contributing

Thanks for helping improve Codex Skill Manager.

This project has a narrow purpose: make project-level Codex skills easy to enable, disable, move, and copy while keeping `.agents/skills/` clean. Changes that protect that focus are much more likely to land than broad agent-management features.

## Local Setup

Requirements:

- macOS 14 or newer
- Xcode Command Line Tools
- Swift 5.9 or newer

Run the project:

```bash
swift test
./script/build_and_run.sh
```

Install a local release build:

```bash
./script/install.sh
```

## Before Opening a Pull Request

Please run:

```bash
swift test
swift build
```

If your change touches app launch, menu bar behavior, or bundle staging, also run:

```bash
./script/build_and_run.sh --verify
```

If your change touches install or release packaging, run:

```bash
./script/package_release.sh
```

## Design Principles

- Keep Codex project skill management the center of the product.
- Prefer simple filesystem behavior over clever abstractions.
- Never silently overwrite a user's skill directory.
- Keep disabled skills outside the project worktree.
- Make destructive-looking actions explicit and reversible where practical.
- Keep the menu bar UI fast and scannable.

## Pull Request Guidelines

- Explain the user problem the change solves.
- Include tests for file movement, conflict handling, or path behavior.
- Keep UI changes small and easy to review.
- Avoid unrelated refactors in feature pull requests.
- Update README or release docs when behavior changes.

## Issue Guidelines

Bug reports are most useful when they include:

- macOS version
- app build method
- project path shape, with private path segments removed if needed
- expected skill location
- actual skill location
- any error shown by the app

Please do not paste private skill contents unless they are directly relevant and safe to share.
