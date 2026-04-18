<p align="center">
  <img src="build/dockishos.png" alt="DockishOS" width="160">
</p>

# DockishOS

DockishOS is a macOS menu-bar utility that adds a floating, per-display app bar for people who use Spaces heavily. It focuses on the windows in the current Space instead of every running app.

The app is built with SwiftUI and AppKit, targets macOS 14+, and ships as an accessory app with no Dock icon.

## Download

Download the current DMG from [GitHub Releases](https://github.com/8bittts/dockishOS/releases), drag DockishOS to `/Applications`, and launch it from there.

Installed app bundles can use Sparkle for update checks. Plain `swift run` builds do not use the bundled app metadata or Sparkle path.

## Features

- Floating bar on each enabled display.
- Window chips for the current Space.
- Optional pinned app row with drag-to-reorder and Finder `.app` drop support.
- Optional grouping of windows by app.
- Click a chip to activate that app and raise the selected window.
- Right-click chips to close windows or pin/unpin apps.
- Vertical scroll over the bar to switch Spaces.
- Collapse the bar into a bottom-left or bottom-right edge tab.
- Launcher hotkey, default `Option-Space`, for opening installed apps.
- Window switcher hotkey, default `Option-Tab`, for cycling windows in the current Space.
- Settings for size, top/bottom placement, titles, badges, hotkeys, login launch, and per-display visibility.

DockishOS does not replace or configure the system Dock. Use System Settings for Dock behavior.

## Permissions

DockishOS asks for Accessibility only when a feature needs it. Accessibility is used to raise or close specific windows and to read optional notification badge text from the Dock accessibility tree.

Window listing and Spaces switching do not require a Screen Recording permission.

Notification badges are off by default. They rely on an undocumented Dock accessibility attribute, so they may stop working on future macOS releases.

## Build

```bash
git clone https://github.com/8bittts/dockishOS.git
cd dockishOS
swift test
./scripts/build_and_run.sh
```

`build_and_run.sh` builds a real app bundle at `build/DockishOS.app` and launches it. Use that path for local app testing because Launch Services, Accessibility, login items, icons, and Sparkle behave differently in a plain `swift run` process.

Useful commands:

```bash
swift build
swift test
./scripts/build_and_run.sh --verify
./scripts/build_and_run.sh --logs
./scripts/build-dmg.sh --build-only
```

## Project Layout

- `Sources/DockishOS`: app, menu bar item, bar UI, launcher, switcher, settings, window and Spaces integration.
- `Sources/DockishOSCore`: testable utility logic.
- `Tests/DockishOSCoreTests`: unit tests.
- `Resources/Info.plist`: app bundle metadata and Sparkle settings.
- `scripts`: local build, DMG, appcast, and release helpers.
- `tools/sparkle`: vendored Sparkle framework used by bundled app builds.

## Contributing

Keep changes native to macOS APIs where possible. Run `swift build` and `swift test` before publishing changes, and use the real bundle script for changes involving Accessibility, login items, app metadata, icons, or updates.

## License

[MIT](LICENSE) © 2026 [@8bittts](https://github.com/8bittts)
