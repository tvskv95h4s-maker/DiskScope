# Contributing to DiskScope

Thanks for helping improve DiskScope. This project is a native macOS app with no
third-party runtime dependencies.

## Development setup

- macOS 14+
- Xcode 15.4+
- Open `DiskScope.xcodeproj`, select the **DiskScope** scheme and run.
- The checked-in project uses the maintainer's Apple Development team. If Xcode
  reports a signing error, choose your own team under **Signing &
  Capabilities**, or build with `CODE_SIGNING_ALLOWED=NO`.

Use the **Release** configuration when you need realistic scan timings. Debug
builds are roughly three times slower because the Swift scanner is unoptimized.

## Code layout

| File | Responsibility |
|---|---|
| `Scanner.swift` | `getattrlistbulk` workers, raw aggregation, tree building |
| `Models.swift` | `DirNode`, `FileItem`, `ScanSummary` |
| `ScanStore.swift` | Scan lifecycle, progress, navigation, permissions |
| `ContentView.swift` | Welcome, scanning and directory browser UI |
| `BigFilesView.swift` | Large-file list, filters and search |
| `Components.swift` | Capacity bar, status bar, formatting |
| `L10n.swift` | Localization helpers and pluralization |

## Localization

Every user-facing string must be localizable:

1. Add a key to `DiskScope/en.lproj/Localizable.strings`, `zh-Hans.lproj` and
   `zh-Hant.lproj`.
2. Use `Text("key")`, `L10n.t("key")` or an `L10n` helper.
3. Counted nouns use `%@` and `L10n.number(_:)` so thousands separators follow
   the user's locale.

To add a language, create `<lang>.lproj/Localizable.strings`, add the file to the
`Localizable.strings` variant group in Xcode, and add the language to
`knownRegions` in `project.pbxproj`.

## Pull requests

- Keep the scanner read-only; never add code that deletes or modifies user files.
- Avoid adding network access or analytics.
- Run a Release build before submitting.
- Describe the user-visible change and include a screenshot for UI work.
- Update `README.md` / `README.zh-CN.md` when behavior changes.

## Reporting bugs

Please include:

- macOS version and Mac model
- DiskScope version (menu → About)
- Steps to reproduce
- Whether Full Disk Access is granted
- Relevant Console logs (`log show --predicate 'process == "DiskScope"' --last 10m`)

## License

By contributing you agree that your changes are licensed under the MIT License.
