# Release Checklist

This project currently ships best as source. Maintainers can use this checklist when preparing a tagged release or a signed macOS app bundle.

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

## 2. Stage the App Bundle

The local build script creates:

```text
dist/CodexSkillManager.app
```

Inspect the bundle:

```bash
plutil -p dist/CodexSkillManager.app/Contents/Info.plist
find dist/CodexSkillManager.app -maxdepth 3 -type f
```

For unsigned source releases, attach the source archive and tell users to build locally.

## 3. Optional Developer ID Signing

For a downloadable app bundle, sign with a Developer ID Application certificate:

```bash
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/CodexSkillManager.app
```

Verify:

```bash
codesign --verify --deep --strict --verbose=2 dist/CodexSkillManager.app
spctl --assess --type execute --verbose=4 dist/CodexSkillManager.app
```

## 4. Optional Notarization

Create a zip for notarization:

```bash
ditto -c -k --keepParent dist/CodexSkillManager.app CodexSkillManager-macos.zip
```

Submit:

```bash
xcrun notarytool submit CodexSkillManager-macos.zip \
  --keychain-profile "notarytool-profile" \
  --wait
```

Staple:

```bash
xcrun stapler staple dist/CodexSkillManager.app
spctl --assess --type execute --verbose=4 dist/CodexSkillManager.app
```

## 5. Publish

Before creating the GitHub release:

- Update `CHANGELOG.md`.
- Tag the release.
- Attach the source archive.
- Attach the signed and notarized zip only if signing and notarization were completed.
- Include the minimum macOS version and build-from-source command in the release notes.
