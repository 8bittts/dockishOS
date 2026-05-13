# Changelog

All notable changes to DockishOS live here. Release tooling reads the
`Unreleased` section for Sparkle and GitHub release notes.

## [Unreleased]

### Changed
- Vendored Sparkle framework is now pinned in `tools/sparkle/VERSION` (2.9.1 / build 2054 + main-binary SHA-256). `scripts/build-dmg.sh` runs a preflight that aborts the build if `Updater.app`, the Installer/Downloader XPC services, or `Autoupdate` is missing, or if the framework binary hash drifts from the pin. `BUILD.md` documents the re-vendor procedure.
- App launcher index now scans `/Applications` on a detached task instead of blocking the main thread on first open.
- Window chips highlight the frontmost window with a 2pt accent leading stripe and a semibold title weight, in addition to the existing opacity delta.
- Bar, window chips, switcher tiles, launcher, and pinned row chrome now use semantic `NSColor` values (`separatorColor`, `selectedContentBackgroundColor`, `controlAccentColor`, `highlightColor`) so affordances stay legible in light mode and high-contrast mode.
- `scripts/build-dmg.sh`, `scripts/build_and_run.sh`, `scripts/generate-appcast.sh`, and `scripts/release-dockishOS.sh` now respond to `-h` / `--help`.

### Tests
- Extracted pure logic into `DockishOSCore` (`HotkeyMask`, `CollapsedTabPlacement`, `SettingsSnapshot`, `WindowGrouping`) with XCTests covering Carbon-mask combinations, legacy persisted-placement migration, settings JSON round-trip, and window grouping by bundle ID + PID fallback.

### Hardening
- `LauncherHotkey.carbonMask(from:)` anchors `HotkeyMask`'s hardcoded bit positions against the live `Carbon.HIToolbox` constants via a static precondition block; future drift in Apple's headers crashes loudly instead of silently mis-registering hotkeys.
- `WindowStore.grouped()` uses `Dictionary(_:uniquingKeysWith:)` so a refresh race that surfaces the same `CGWindowID` twice no longer traps the process.

## [0.016]

### Fixed
- Auto-update no longer fails with "An error occurred while launching the installer." The vendored Sparkle.framework was missing `Versions/B/Updater.app`, which Sparkle 2.7+ requires as its progress/authorization helper. Existing 0.014 and 0.015 installs have the same broken framework and must reinstall manually from the 0.016+ DMG to recover auto-update.

## [0.015]

### Fixed
- Menu bar status item shows the full DockishOS app icon again (regression in 0.014 swapped it for a generic SF Symbol).

### Tests
- Added a source-level regression guard (`MenuBarIconRegressionTests`) that fails if the status item icon is reverted to a generic SF Symbol.

## [0.014]

### Fixed
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
