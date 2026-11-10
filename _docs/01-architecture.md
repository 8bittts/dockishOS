# Architecture

Targets, modules and data flow of DockishOS; the constraints that bind changes are in `AGENTS.md`.

## Stack

A SwiftPM macOS menu-bar utility for macOS 14 and later on Apple Silicon, built with SwiftUI and AppKit and shipped as an accessory app with no Dock icon.
The package builds in the Swift 6 language mode, so the compiler checks data-race safety: every type that touches AppKit or shared state is `@MainActor`.
`Package.swift` defines two targets: `DockishOSCore`, the AppKit-free and Carbon-free logic that `swift test` covers, and `DockishOS`, the app that composes it with AppKit, Accessibility and private CoreGraphics Spaces APIs.
Sparkle is vendored for updates; distribution is a notarized DMG and a Homebrew Cask ([05-infrastructure.md](05-infrastructure.md)).

## Core target

`Sources/DockishOSCore` holds pure logic with unit tests in `Tests/DockishOSCoreTests`; its declarations are `package`-level, visible to the app and the tests and to nothing outside this package:

| Type                        | Owns                                                         |
| --------------------------- | ------------------------------------------------------------ |
| `AppSearchScorer`           | Launcher ranking: exact, prefix, word-prefix, contains, ordered-character matches |
| `BarGeometry`               | Bar sizing and placement math                                |
| `BoundedIndex`, `SelectionWrap`, `WindowCycle` | Selection movement and wrap-around for the switcher and launcher |
| `CollapsedTabPosition`      | Which screen corner holds the collapsed edge tab             |
| `DisplayNameDisambiguator`  | Distinct names for same-named apps or windows                |
| `StableIDReordering`        | Drag-to-reorder for the pinned row                           |
| `WindowInfo`, `AppWindowGroup`, `WindowGrouping` | A window as the window server lists it, and optional grouping of windows by app |

## App target

- Bar: `BarController`, `BarPanel`, `BarView`, `WindowChips`, `PinnedRow`, `CollapsedBarTab` and `BarSupport` render one floating bar per enabled display, show window chips for the current Space, the optional pinned row with Finder `.app` drop support, and the collapse into a bottom-left or bottom-right edge tab.
- Launcher: `LauncherController`, `LauncherView` and `LauncherStore` open on `Option-Space` and search `AppIndex`, the installed-app index.
- Switcher: `SwitcherController`, its `SwitcherPanel` and `SwitcherView` open on `Option-Tab` and cycle the current Space's windows with Tab, Shift-Tab, the arrow keys, Return and Escape; the panel reads those keys, because the SwiftUI content holds no keyboard focus.
- Panels: `HUDPanel` is the non-activating, fixed-size key panel behind both the launcher and the switcher ([00-foundation.md](00-foundation.md) records why).
- Hotkeys: `Hotkey` is the stored chord and `HotkeyManager` registers one per `HotkeyAction` through Carbon; `HotkeyRecorder` is the Settings field that records a new chord.
- Windows and Spaces: `WindowEnumerator`, `WindowStore` and `RunningAppsStore` list windows and apps; `WindowControl` and `AXHelper` raise or close a specific window through Accessibility; `SpacesAPI` reads and switches Spaces through private CGS SPIs, on demand and with no polling; `ScreenHelpers` maps displays.
- Badges: `BadgeStore` reads optional notification badge text from the Dock accessibility tree; off by default.
- Persistence: `PinnedAppsStore` and `Settings` keep pinned apps and preferences; `SettingsController` and `SettingsView` present the `Cmd-,` window for size, placement, titles, badges, hotkeys, login launch and per-display visibility.
- Shell: `main.swift`, `AppDelegate`, `MenuBarController` (status menu with Previous Space and Next Space), `AppActivation`, `Permissions`, `LoginItem`, `Updater` (Sparkle), `Diagnostics`, `AppVersion` and `DockishBrandAssets`.
- Plumbing: `MainActorCallbacks` gives notification observers and repeating timers main-actor handlers, and `PrivateSymbol` resolves private system functions at run time.

## Bundle

`Resources/Info.plist` carries the bundle metadata, `LSUIElement` and the Sparkle keys (`SUFeedURL`, `SUPublicEDKey`, `SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`).
The version in `Resources/Info.plist` is the source of truth and the release script bumps it.
`public/` holds README and product media and `docs/index.md` is the GitHub Pages landing.

## Build pipeline

`swift build` and `swift test` validate the package; `./scripts/build_and_run.sh` builds a real bundle at `build/DockishOS.app` and launches it, because Launch Services, Accessibility, login items, icons and Sparkle behave differently in a plain `swift run` process.
Release packaging, signing, distribution and Sparkle vendoring are [05-infrastructure.md](05-infrastructure.md); the gates are [09-quality.md](09-quality.md).
