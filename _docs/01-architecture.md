# Architecture

Targets, modules and data flow of DockishOS; the constraints that bind changes are in `AGENTS.md`.

## Stack

A SwiftPM macOS menu-bar utility for macOS 14 and later on Apple Silicon, built with SwiftUI and AppKit and shipped as an accessory app with no Dock icon.
`Package.swift` defines two targets: `DockishOSCore`, the AppKit-free and Carbon-free logic that `swift test` covers, and `DockishOS`, the app that composes it with AppKit, Accessibility and private CoreGraphics Spaces APIs.
Sparkle is vendored for updates; distribution is a notarized DMG and a Homebrew Cask ([05-infrastructure.md](05-infrastructure.md)).

## Core target

`Sources/DockishOSCore` holds pure logic with unit tests in `Tests/DockishOSCoreTests`:

| Type                        | Owns                                                         |
| --------------------------- | ------------------------------------------------------------ |
| `AppSearchScorer`           | Launcher ranking: exact, prefix, word-prefix, contains, ordered-character matches |
| `BarGeometry`               | Bar sizing and placement math                                |
| `BoundedIndex`, `SelectionWrap`, `WindowCycle` | Selection movement and wrap-around for the switcher and launcher |
| `CollapsedTabPlacement`     | Where the collapsed edge tab sits                            |
| `DisplayNameDisambiguator`  | Distinct names for same-named apps or windows                |
| `HotkeyMask`                | Modifier handling for the configurable hotkeys               |
| `StableIDReordering`        | Drag-to-reorder for the pinned row                           |
| `WindowGrouping`            | Optional grouping of windows by app                          |

## App target

- Bar: `BarController`, `BarPanel`, `BarView`, `WindowChips`, `PinnedRow`, `CollapsedBarTab` and `BarSupport` render one floating bar per enabled display, show window chips for the current Space, the optional pinned row with Finder `.app` drop support, and the collapse into a bottom-left or bottom-right edge tab.
- Launcher: `LauncherController`, `LauncherPanel`, `LauncherView`, `LauncherStore` and `LauncherHotkey` open on `Option-Space` and search `AppIndex`, the installed-app index.
- Switcher: `SwitcherController` and `SwitcherView` open on `Option-Tab` and cycle the current Space's windows with Tab, Shift-Tab, the arrow keys, Return and Escape.
- Hotkeys: `HotkeyManager` registers both hotkeys, which Settings can change.
- Windows and Spaces: `WindowEnumerator`, `WindowStore` and `RunningAppsStore` list windows and apps; `WindowControl` and `AXHelper` raise or close a specific window through Accessibility; `SpacesAPI` and `SpacesStore` read and switch Spaces through private CGS SPIs; `ScreenHelpers` maps displays.
- Badges: `BadgeStore` reads optional notification badge text from the Dock accessibility tree; off by default.
- Persistence: `PinnedAppsStore` and `Settings` keep pinned apps and preferences; `SettingsController` and `SettingsView` present the `Cmd-,` window for size, placement, titles, badges, hotkeys, login launch and per-display visibility.
- Shell: `main.swift`, `AppDelegate`, `MenuBarController` (status menu with Previous Space and Next Space), `AppActivation`, `Permissions`, `LoginItem`, `Updater` (Sparkle), `Diagnostics`, `AppVersion` and `DockishBrandAssets`.

## Bundle

`Resources/Info.plist` carries the bundle metadata, `LSUIElement`, the Accessibility usage description and the Sparkle keys (`SUFeedURL`, `SUPublicEDKey`, `SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`).
The version in `Resources/Info.plist` is the source of truth and the release script bumps it.
`public/` holds README and product media and `docs/index.md` is the GitHub Pages landing.

## Build pipeline

`swift build` and `swift test` validate the package; `./scripts/build_and_run.sh` builds a real bundle at `build/DockishOS.app` and launches it, because Launch Services, Accessibility, login items, icons and Sparkle behave differently in a plain `swift run` process.
Release packaging, signing, distribution and Sparkle vendoring are [05-infrastructure.md](05-infrastructure.md); the gates are [09-quality.md](09-quality.md).
