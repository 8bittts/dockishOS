# Changelog

All notable changes to DockishOS live here. Release tooling reads the
`Unreleased` section for Sparkle and GitHub release notes.

## [Unreleased]

## [0.023]

### Fixed
- Sparkle's update window and its alerts now reliably come to the front. As an accessory (menu-bar) app DockishOS can't foreground itself, so the "update available" window opened behind other apps and was easy to miss. The updater now acts as Sparkle's user-driver delegate: for the duration of an update session it temporarily promotes the app to a regular foreground app and floats the Sparkle windows above everything, then restores both the activation policy and window levels when the session ends.

### Changed
- Documented the graphify code-orientation workflow and ignored generated graph artifacts in the repo.
- Removed the unused `SettingsSnapshot` helper and its tests from `DockishOSCore`; settings persistence now stays owned by the app target's `SettingsStore`.
- Removed the GitHub Sponsors funding metadata from `.github/FUNDING.yml`.

## [0.022]

### Changed
- Live auto-update verification release. No app behavior changes between 0.021 and 0.022; the purpose was to exercise the 0.021 → next-version Sparkle path end-to-end with the missing-symlink, helper-signing-order, and `Updater.app`-present fixes all stacked.

## [0.021]

### Fixed
- Auto-update finally works end-to-end. The 0.014 → 0.020 builds all shipped without the top-level `Sparkle.framework/Updater.app -> Versions/Current/Updater.app` symlink that `NSBundle.URLForAuxiliaryExecutable()` walks to find the progress/authorization helper. With the symlink absent, Sparkle's installer launcher returned nil for `Updater.app` and aborted with "Cannot retrieve path for auxiliary tool" → "An error occurred while launching the installer." The 0.016/0.019 fixes (re-adding `Updater.app` to `Versions/B/`, then re-ordering the inner-Mach-O signing) were both necessary hygiene but not the actual cause. Vendored framework now matches the official Sparkle 2.9.1 layout exactly. `tools/sparkle/VERSION` lists the symlink in `required_paths` so the build-time preflight refuses to package a framework that's missing it.

## [0.020]

### Changed
- Live verification release for the Sparkle signing fix that shipped in 0.019. No app behavior changes between 0.019 and this build; the purpose was to exercise the 0.019 → next-version Sparkle auto-update path end-to-end now that the helper signing order produces a consistent framework seal. The test revealed the real bug, fixed in 0.021.

## [0.019]

### Fixed
- Auto-update could fail with "An error occurred while launching the installer." again on a fresh 0.016/0.017/0.018 install when Sparkle's `Updater.app` disappeared from the bundled framework between launch and first Check-for-Updates click. Root cause: `scripts/build-dmg.sh` re-signed the `.xpc` / `.app` helper wrappers without first re-signing their inner Mach-Os, leaving the wrapper's `CodeResources` referencing an inconsistent inner signature. macOS treated `Updater.app` as a broken sealed resource and removed it on the next launch validation pass. Signing now follows Sparkle's upstream recipe verbatim: inner binary first, then the wrapping bundle, then the framework. `codesign --verify --deep --strict` now lists `Updater.app` in the validation chain (it was previously skipped).

### Changed
- Repo doubles as a Homebrew tap. Cask formula moved to `Casks/dockishos.rb` (capital C is the Homebrew convention). README documents `brew install --cask <URL>` and `brew tap` flows.

## [0.018]

### Changed
- README now closes with a "Built with YEN" cross-promotion block matching the footer used in `8bittts/movingpaper`.
- New `.github/FUNDING.yml`, `docs/index.md` (GitHub Pages landing), and reference `Casks/dockishos.rb` Homebrew Cask formula.

## [0.017]

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
