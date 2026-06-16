# Release Checklist

The recommended public install path is source-built local install with `./script/install.sh`. GitHub release archives are useful for convenience, but macOS may warn on first launch.

## 1. Verify the Source Tree

Run:

```bash
swift test
swift build
./script/build_and_run.sh --verify
```

Confirm:

- Tests pass.
- The app launches.
- The menu bar item appears.
- A sample project can enable and disable a skill.
- Disabled skills land under `~/Library/Application Support/CodexSkillManager/InactiveSkills/`.

## 2. Test Local Install

Run:

```bash
./script/install.sh --user
```

This builds a release app, installs it to:

```text
~/Applications/CodexSkillManager.app
```

For a machine-wide install:

```bash
./script/install.sh --system
```

## 3. Create a Release Archive

Run:

```bash
VERSION=0.1.0 ./script/package_release.sh
```

The package script creates:

```text
dist/release/CodexSkillManager-0.1.0-macos.zip
dist/release/CodexSkillManager-0.1.0-macos.zip.sha256
```

It also ad-hoc signs the app bundle. Ad-hoc signing is enough for local integrity checks, but it is not the same as Developer ID signing.

Inspect the app bundle:

```bash
plutil -p dist/CodexSkillManager.app/Contents/Info.plist
find dist/CodexSkillManager.app -maxdepth 3 -type f
codesign --verify --deep --strict --verbose=2 dist/CodexSkillManager.app
```

## 4. Publish a GitHub Release

Push a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow runs tests, creates the archive, writes a SHA-256 checksum, and attaches both files to the GitHub release.

Release notes should include:

- The recommended source install command:

```bash
git clone https://github.com/code-by-adil/codex-skill-manager.git
cd codex-skill-manager
./script/install.sh
```

- A note that macOS users may need to right-click the app and choose Open the first time.
- The minimum macOS version.

## 5. Optional Developer ID Path

If maintainers later want signed downloads, the same staged app can be Developer ID signed and notarized:

```bash
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/CodexSkillManager.app
```

Then zip, submit with `xcrun notarytool`, staple with `xcrun stapler`, and validate with:

```bash
spctl --assess --type execute --verbose=4 dist/CodexSkillManager.app
```
