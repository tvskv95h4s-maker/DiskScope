# Releasing DiskScope

## 1. Bump the version

`MARKETING_VERSION` lives in `DiskScope.xcodeproj/project.pbxproj` (two target
configurations). Set it to the new semantic version, for example `0.1.0`, and
update `CHANGELOG.md`.

## 2. Build and package

```bash
./scripts/package.sh
# -> dist/DiskScope-<version>.dmg
```

The packaging script uses Finder AppleScript to arrange the DMG window
(background, icon positions). macOS will ask for Automation permission the first
time — allow it, otherwise the DMG is created without the guide layout.

Verify the DMG:

```bash
hdiutil attach dist/DiskScope-<version>.dmg
open "/Volumes/DiskScope <version>/DiskScope.app"
hdiutil detach "/Volumes/DiskScope <version>"
```

## 3. Sign and notarize (recommended for public downloads)

You need an Apple Developer Program membership and a **Developer ID
Application** certificate in your keychain.

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package.sh
```

Store notarization credentials once:

```bash
xcrun notarytool store-credentials "diskscope-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Submit and staple:

```bash
xcrun notarytool submit dist/DiskScope-<version>.dmg \
  --keychain-profile "diskscope-notary" --wait

xcrun stapler staple dist/DiskScope-<version>.dmg
spctl --assess --type open --context context:primary-signature -v dist/DiskScope-<version>.dmg
```

Without notarization the DMG still works, but users must right-click the app and
choose **Open** the first time.

## 4. Publish

1. Create a Git tag: `git tag v0.1.0 && git push origin main --tags`.
2. On GitHub, open **Releases → Draft a new release**, choose the tag, and attach
   `dist/DiskScope-<version>.dmg`.
3. Paste the matching section of `CHANGELOG.md` into the release notes.

## 5. Homebrew (optional)

A cask is a nice follow-up:

```ruby
cask "diskscope" do
  version "0.1.0"
  sha256 "..."
  url "https://github.com/<owner>/DiskScope/releases/download/v#{version}/DiskScope-#{version}.dmg"
  name "DiskScope"
  desc "Native macOS disk usage analyzer"
  homepage "https://github.com/<owner>/DiskScope"
  app "DiskScope.app"
end
```
