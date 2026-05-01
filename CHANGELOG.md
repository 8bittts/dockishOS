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
- Dock badge lookup no longer assumes the Dock list is the first Accessibility child.
- Space switching now confirms the private CGS switch landed before updating cached state.
- Shift-Tab now cycles backward in the window switcher.
- Settings, switcher tiles, and destructive window actions have better accessibility behavior.

### Changed
- README now includes a product bar preview image.
- README and build docs now describe first launch, release markers, and local build modes.
- Removed unused Dock auto-hide helper code.
