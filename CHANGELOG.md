# Changelog

All notable changes to DockishOS live here. Release tooling reads the
`Unreleased` section for Sparkle and GitHub release notes.

## [Unreleased]

### Fixed
- Menu bar icon now uses a template image so macOS can tint it correctly.
- Release packaging now aborts on rejected notarization or failed stapling.
- Release retries can resume an existing tag/release without bumping again.
- Hotkey registration failures are surfaced from the menu bar item.
- Window activation now uses macOS 14 cooperative activation.
- Fullscreen Space window enumeration and Space numbering are more robust.
- Dock badge polling uses an Accessibility messaging timeout.
- Settings, switcher tiles, and destructive window actions have better accessibility behavior.

### Changed
- README and build docs now describe first launch, release markers, and local build modes.
