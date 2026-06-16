# Security Policy

Codex Skill Manager is a local macOS utility that moves skill directories between a Codex project's active skill folder and app-owned inactive storage.

## Supported Versions

Security fixes are handled on the main branch until the project begins publishing versioned releases.

## Reporting a Vulnerability

Please open a private security advisory on GitHub if the repository has advisories enabled. If not, open an issue with a minimal description and ask for a maintainer contact before sharing sensitive details.

Useful reports include:

- Affected version or commit
- macOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Why the behavior could cause data loss, privilege problems, or unintended file access

## Security Boundaries

The app is designed to:

- Manage project-level skill directories selected by the user.
- Store disabled skills in the user's Application Support directory.
- Avoid overwriting existing destination skill directories.
- Avoid deleting project files when removing a project from the app.

The app is not designed to:

- Sandbox or audit the contents of skills.
- Validate whether a skill is safe to use with an agent.
- Manage global skills.
- Sync skills to remote services.

Review third-party skills before enabling them in a project.
