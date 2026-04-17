# DockishOS

**A native macOS taskbar that organizes windows by Space.**

A free, open-source Dock alternative for people who actually use macOS Spaces. Built from scratch with AppKit + SwiftUI, no third-party dependencies, no analytics, no telemetry.

<!-- version-badge -->v0.004<!-- /version-badge --> · macOS 14+ · Swift 5.10+ · MIT

[![macOS](https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](https://swift.org/package-manager/)
[![License](https://img.shields.io/github/license/8bittts/dockishOS)](LICENSE)

> **Status:** Early. Functional foundation: per-monitor floating bar, Spaces switcher, per-window raise, hover thumbnails, app launcher. See [Roadmap](#roadmap).

---

## Download

<!-- download-link -->
[**Download DockishOS v0.004**](https://github.com/8bittts/dockishOS/releases/download/v0.004/DockishOS-0.004.dmg)
<!-- /download-link -->

When releases are published they will be code-signed with a Developer ID and notarized by Apple. Open the `.dmg`, drag **DockishOS** to `/Applications`, launch it. Look for the floating bar at the bottom of every display and the dock-shaped icon in the menu bar.

---

## Overview

DockishOS adds a translucent floating bar at the bottom of every display. Each bar shows:

- **Spaces row** — numbered chips for every virtual desktop on that display, current one highlighted, click to switch.
- **Windows row** — chips for every window on the *current* Space (not every running app), with the frontmost window outlined in your accent color. Click to raise the specific window.

It is designed for people who use macOS Spaces heavily and find the default Dock unhelpful at telling them what is actually open right now.

> **Note:** DockishOS does not hide the system Dock. Set System Settings → Desktop & Dock → "Automatically hide and show the Dock" yourself if you want it gone.

---

## Quick start

```bash
git clone https://github.com/8bittts/dockishOS.git
cd dockishOS
./scripts/build_and_run.sh        # stages a real .app bundle and launches it
# or, for a quick non-bundled run:
swift run DockishOS
```

The app launches as a menu-bar accessory (no Dock icon, no `Cmd+Tab` entry). A bar appears at the bottom of every connected display. Quit from the menu bar item (the dock-shaped icon) → **Quit DockishOS**.

> **Tip:** First click on a window chip will trigger the macOS Accessibility prompt. First hover that lasts 200 ms will trigger the Screen Recording prompt. Grant both in System Settings → Privacy & Security, then re-launch.

---

## Topics

### Spaces

The leftmost section of every bar shows the Spaces (virtual desktops) that exist on the bar's display. The current Space is rendered as a solid white chip; the others are translucent.

| Action | Result |
|---|---|
| Click chip `N` | Switch to Space N on this display |
| Add / remove a Space in Mission Control | Bar refreshes within 5 s (or immediately on next Space switch) |

DockishOS reads Spaces via the private `CGSCopyManagedDisplaySpaces` SPI and switches via `CGSManagedDisplaySetCurrentSpace`. See [Private API surface](#private-api-surface). No permission grant is required.

> **Important:** macOS has a "Displays have separate Spaces" toggle (System Settings → Desktop & Dock → Mission Control). DockishOS handles both modes — when off, every display shows the same Space list.

### Windows

The right side of every bar lists windows that are on-screen *on the current Space*. The list updates every second and immediately on `activeSpaceDidChange` and `didActivateApplication` notifications.

| Action | Result |
|---|---|
| Click chip | Activate the owning app **and** raise that specific window via `AXUIElement` + `kAXRaiseAction` |
| Right-click chip → Activate | Same as click |
| Right-click chip → Close Window | Press the AX close button on that window |
| Hover chip (200 ms) | Floating thumbnail preview of the window via ScreenCaptureKit |
| Hover chip | Tooltip with the full window title |
| Scroll vertically over bar | Switch to previous / next Space (250 ms cooldown) |

When **Group windows by app** is enabled in Settings → Appearance, multiple windows of the same app collapse to one chip with a count badge. Click cycles through windows of that app; right-click lists each window by title and offers **Close All Windows**.

> **Note:** Without Screen Recording permission, foreign-app window titles are redacted by macOS to the empty string. The chip falls back to the owning app's name (e.g., "Safari", "Terminal"). With Screen Recording, you get titles like "Inbox - Mail" or "AppDelegate.swift — DockishOS".

### Pinned apps

A row of pinned-app chips lives between the Spaces and Windows rows. Each chip shows the app's icon plus a small running-state dot.

| Action | Result |
|---|---|
| Click chip | Activate the app if running, otherwise launch it |
| Drag chip onto another | Reorder pins |
| Drag a `.app` from Finder onto the bar | Pin that app |
| Right-click → Move Left / Right | Reorder the pin (chevron alternative) |
| Right-click → Unpin | Remove the pin |

To add a pin, drag a `.app` from Finder onto any spot on the bar, right-click any window chip on the bar (**Pin App to Bar**), or right-click any result in the launcher (**Pin to Bar**). Order is persisted across launches in `UserDefaults`.

### Settings

Press **⌘,** (or pick **Settings…** from the menu-bar item) to open the Settings window:

| Tab | Controls |
|---|---|
| **Appearance** | Bar size (S / M / L), bar position (Top / Bottom), show window titles toggle, show pinned apps row toggle |
| **Behavior** | Customize launcher hotkey, auto-hide system Dock, launch DockishOS at login, per-display opt-in/out |
| **Pinned** | Reorder or unpin individual apps; manage the pinned list |
| **About** | Version + build, links to repo, releases, and license |

Bar size and position changes apply immediately to every connected display — the bars are torn down and rebuilt. Hotkey changes re-register the global Carbon hotkey on the fly.

### Menu bar

A small dock-shaped icon appears in the system menu bar:

| Item | |
|---|---|
| Open Launcher | Same as ⌥ Space |
| Settings… | ⌘, — open the Settings window |
| Open GitHub Repo | Open the project page in your browser |
| Quit DockishOS | ⌘Q — cleanly exit the app |

The menu-bar item is the only built-in way to quit when DockishOS was launched from the `.app` bundle (no terminal attached).

### Launcher

Press **⌥ Space** (Option+Space) to open the app launcher. Type to fuzzy-search every `.app` in `/Applications`, `/System/Applications`, and `~/Applications`. Arrow keys to navigate, `Return` to launch, `Escape` or click outside to dismiss.

| Action | Key |
|---|---|
| Toggle launcher | ⌥ Space (configurable) |
| Move selection | ↑ / ↓ |
| Launch selected app | Return |
| Dismiss | Esc / click outside |

Both the launcher and switcher hotkeys are user-configurable in Settings → Behavior → Hotkeys.

### App switcher

Press **⌥ Tab** (default) to open the app switcher: a horizontal grid of icons for every window on the current Space. Useful as a Cmd+Tab replacement that respects Spaces.

| Action | Key |
|---|---|
| Toggle switcher | ⌥ Tab (configurable) |
| Cycle selection | Tab, →, ← |
| Activate selected window | Return |
| Dismiss | Esc / click outside |

### Auto-update

Once installed from the DMG, DockishOS checks for updates hourly via [Sparkle](https://sparkle-project.org). When a new release is available, the standard Sparkle dialog appears.

| Element | Detail |
|---|---|
| Feed | `https://github.com/8bittts/dockishOS/releases/latest/download/appcast.xml` |
| Signature | EdDSA, public key embedded in `Info.plist` |
| Verification | `SUVerifyUpdateBeforeExtraction` + `SURequireSignedFeed` enforced |
| Manual check | **Check for Updates…** in the menu bar item |

`swift run` and `build_and_run.sh` builds skip Sparkle wiring entirely — auto-update only takes effect inside a real `.app` bundle.

### Permissions

DockishOS requests permissions **lazily**, only when you first use a feature that needs them.

| Permission | Required for | Prompted when |
|---|---|---|
| Accessibility | Per-window raise + close | First click on a window chip |
| Screen Recording | Window titles + hover thumbnails | First hover that lasts 200 ms over a window chip |

Spaces enumeration and switching require **no** permissions — the CGS SPIs operate without sandbox checks.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      NSApplication (.accessory)             │
│                              │                              │
│                       AppDelegate                           │
│           ┌──────────────────┼──────────────────┐           │
│           ▼                  ▼                  ▼           │
│    BarController       BarController       BarController    │
│      (screen 1)          (screen 2)          (screen 3)     │
│           │                  │                  │           │
│           ▼                  ▼                  ▼           │
│       BarPanel           BarPanel           BarPanel        │
│      (NSPanel)          (NSPanel)          (NSPanel)        │
│           │                  │                  │           │
│           └──────────┬───────┴────────┬─────────┘           │
│                      ▼                ▼                     │
│               WindowStore       SpacesStore                 │
│                      │                │                     │
│                      ▼                ▼                     │
│            WindowEnumerator      SpacesAPI                  │
│            (CGWindowList)        (private CGS)              │
│                      │                                      │
│                      ▼                                      │
│              WindowControl                                  │
│              (AX + private)                                 │
└─────────────────────────────────────────────────────────────┘
```

| File | Responsibility |
|---|---|
| `main.swift` | Entry point. Sets `.accessory` activation policy, runs the app. |
| `AppDelegate.swift` | Owns one `BarController` per `NSScreen`. Observes screen + Space changes. |
| `BarController.swift` | Builds and shows one bar window for one screen. |
| `BarPanel.swift` | Borderless `NSPanel` at `.statusBar` level, joins all Spaces, full-screen aux. |
| `BarView.swift` | SwiftUI bar UI: Spaces chips on the left, windows on the right. |
| `WindowEnumerator.swift` | `CGWindowListCopyWindowInfo` wrapper. Public API only. |
| `WindowControl.swift` | AX-based window raise + close. Bridges CGWindowID ↔ AXUIElement. |
| `SpacesAPI.swift` | Private `CGS*` Spaces SPI bindings. |
| `ThumbnailCapture.swift` | One-shot ScreenCaptureKit capture by `CGWindowID`. |
| `ThumbnailController.swift` | Singleton floating panel that shows a window thumbnail on hover. |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` wrapper for one global hotkey. |
| `AppIndex.swift` | Recursive `.app` scanner + Spotlight-style scoring. |
| `LauncherStore.swift` | `ObservableObject` for query, results, selection. |
| `LauncherPanel.swift` | Key-eligible `NSPanel` for the launcher. |
| `LauncherView.swift` | SwiftUI launcher UI with arrow-key navigation. |
| `LauncherController.swift` | Show / hide / position; restores prior frontmost on dismiss. |
| `MenuBarController.swift` | Status-bar `NSStatusItem` with Quit, Open Launcher, Settings, Open Repo. |
| `Settings.swift` | `BarSize` + `BarPosition` enums, `SettingsStore` (UserDefaults-backed). |
| `PinnedAppsStore.swift` | UserDefaults-backed list of pinned apps + load / save / launch helpers. |
| `SettingsView.swift` | SwiftUI `TabView`: Appearance / Behavior / Pinned / About. |
| `SettingsController.swift` | Single-instance Settings `NSWindow`. |
| `LauncherHotkey.swift` | `LauncherHotkey` model + `HotkeyRecorderView` for in-app rebinding. |
| `DockHelper.swift` | Read + toggle the system Dock's `autohide` preference (defaults / killall). |
| `LoginItem.swift` | `SMAppService.mainApp` register / unregister wrapper. |
| `SwitcherController.swift` | App-switcher panel lifecycle (⌥ Tab). |
| `SwitcherView.swift` | SwiftUI horizontal-grid window switcher. |
| `Updater.swift` | `SPUStandardUpdaterController` wrapper, only active in `.app` bundles. |
| `tools/sparkle/Sparkle.framework` | Vendored Sparkle 2.x binary framework, copied into `Contents/Frameworks/` at build time and signed with the app's identity. |
| `scripts/generate-appcast.sh` | Sparkle's `generate_appcast` wrapped with release-notes-from-git and signed-feed verification. |
| `WindowStore.swift` | `ObservableObject` for windows. Refreshes on tick + activation + Space change. |
| `SpacesStore.swift` | `ObservableObject` for Spaces. Refreshes on Space change + 5 s polling. |
| `Permissions.swift` | Accessibility check + prompt helpers. |

---

## Private API surface

DockishOS uses two private symbol surfaces. Both have been stable across roughly a decade of macOS releases and are used by every comparable tool (yabai, Rectangle, AltTab, Spaceman, Mission Control Plus). Apple tolerates this usage but reserves the right to break it; calls are wrapped in graceful fallbacks.

### `_AXUIElementGetWindow`

```c
AXError _AXUIElementGetWindow(AXUIElement element, CGWindowID *windowID);
```

Maps an `AXUIElement` (Accessibility window) back to its `CGWindowID`. Used to find *which* AX window corresponds to the chip the user clicked. Lives in `ApplicationServices.framework`. Bound in `WindowControl.swift`.

### CGS Spaces functions

```c
CGSConnectionID CGSMainConnectionID(void);
CFArrayRef      CGSCopyManagedDisplaySpaces(CGSConnectionID cid);
CGSSpaceID      CGSManagedDisplayGetCurrentSpace(CGSConnectionID cid, CFStringRef display);
void            CGSManagedDisplaySetCurrentSpace(CGSConnectionID cid, CFStringRef display, CGSSpaceID space);
```

Enumerate Spaces grouped by display, read current Space, switch Spaces. Live in `CoreGraphics.framework`. Bound in `SpacesAPI.swift`.

> **Warning:** If Apple ever ships a public Spaces API, DockishOS will migrate eagerly and delete these bindings. Until then, this is the only way.

---

## Build from source

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 16 or later (Command Line Tools sufficient)
- Swift 5.10+
- For DMG packaging: nothing extra
- For notarization: an Apple Developer ID and a configured notary keychain profile (see [Release pipeline](#release-pipeline))

### Day-to-day

```bash
swift build                       # Debug build → .build/debug/DockishOS
swift run DockishOS               # Build + run (no real .app bundle)
./scripts/build_and_run.sh        # Stage a real .app bundle in build/local-run/ and launch it
./scripts/build_and_run.sh --logs # Same, with `log stream` attached
open Package.swift                # Open in Xcode (SwiftPM manifest is the project)
```

Use `swift run` for trivial code paths. Use `build_and_run.sh` whenever you need real `Info.plist` behaviors (`LSUIElement`, permission usage strings, the menu bar item) or you're testing anything that reads from the bundled `Info.plist`.

### Release pipeline

Three scripts live in `scripts/`. They mirror the pattern used by the [movingpaper](https://github.com/8bittts/movingpaper) project:

| Script | Purpose |
|---|---|
| `scripts/build_and_run.sh` | Dev runner. Stages and launches a real `.app` bundle. |
| `scripts/build-dmg.sh` | Build, sign, package, optionally notarize. Produces `build/DockishOS-<version>.dmg`. |
| `scripts/release-dockishOS.sh` | End-to-end: bump `Resources/Info.plist` version, build, tag, push, draft GitHub release. |

**Quick local DMG (no Developer ID required):**

```bash
./scripts/build-dmg.sh --unsigned   # Ad-hoc sign, draggable .dmg
```

**Signed but not notarized (faster than full release):**

```bash
./scripts/build-dmg.sh --local
```

**Full notarized release (requires keychain profile):**

```bash
./scripts/build-dmg.sh
```

**Cut a new tagged GitHub release:**

```bash
./scripts/release-dockishOS.sh
```

The release script bumps the `0.001` → `0.002` style version in `Resources/Info.plist`, runs `build-dmg.sh`, commits the bump, tags `v<version>`, pushes, and uses `gh release create` to publish the DMG + checksum.

### Notarization setup (one-time)

```bash
xcrun notarytool store-credentials YEN-Notarization \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password YOUR_APP_SPECIFIC_PASSWORD
```

Override the profile name per-build with `DOCKISHOS_NOTARY_PROFILE=…`.

### Sparkle EdDSA key (one-time)

The release pipeline signs the appcast with an EdDSA key stored in your macOS keychain. To generate one:

```bash
./tools/sparkle/bin/generate_keys
```

This writes a private key to your login keychain (auto-approved if you've used Sparkle before) and prints the public key. Copy that public key into `Resources/Info.plist` under `SUPublicEDKey`. The same private key can sign appcasts for every Sparkle-enabled app you ship — only one key per developer is needed.

### From a Claude Code session

The global `/build-dockishOS` slash command wraps the scripts above. Run it from any directory; it `cd`s into the repo automatically.

---

## Roadmap

Done:

- [x] Per-monitor floating bar
- [x] Current-Space window enumeration
- [x] Per-window AX raise + close
- [x] Spaces row with click-to-switch
- [x] Frontmost window indicator
- [x] Scroll wheel over bar to switch Spaces
- [x] Window thumbnails on hover (ScreenCaptureKit)
- [x] App launcher with global hotkey (⌥ Space)
- [x] Menu-bar item with Quit / Open Launcher / Open Repo
- [x] Bundle as `.app` with proper `Info.plist` + permission usage strings
- [x] DMG build + notarization pipeline modeled on movingpaper
- [x] First tagged GitHub release with notarized `.dmg` download (v0.002)
- [x] Pinned apps row backed by UserDefaults
- [x] Settings window with Bar size (S/M/L), chip titles toggle, pinned-row toggle
- [x] About panel with version + license + acknowledgments
- [x] Bar position (Top / Bottom)
- [x] System Dock auto-hide toggle (Settings + menu bar)
- [x] Auto-launch on login via `SMAppService`
- [x] Per-monitor opt-in / opt-out
- [x] Customizable launcher hotkey
- [x] Drag-to-reorder pinned apps
- [x] Drag `.app` bundles from Finder onto the bar to pin
- [x] Optional window grouping by app (one chip per app, count badge)
- [x] App switcher (⌥ Tab replacement for Cmd+Tab, scoped to current Space)
- [x] Sparkle auto-update wired to the GitHub Releases appcast (signed feed)

Open:

- [ ] Notification badge counts on app icons (no public API for foreign-app badges — likely deferred)

---

## Contributing

Issues and pull requests welcome. A few ground rules:

- **Native APIs first.** Reach for `AXUIElement` / `CGS*` before pulling in dependencies.
- **Main thread for UI + AX + CGS.** No background queues touching SwiftUI, AppKit, Accessibility, or Core Graphics Services.
- **No telemetry.** Not now, not ever.
- **Run `swift build` clean before opening a PR.** No warnings, no broken SPIs.

If you're adding a new feature that requires a permission, prompt for it lazily on first use — not at launch.

---

## License

[MIT](LICENSE) © 2026 [@8bittts](https://github.com/8bittts)

---

## Acknowledgments

- [yabai](https://github.com/koekeishiya/yabai), [AltTab](https://github.com/lwouis/alt-tab-macos), [Spaceman](https://github.com/Jaysce/Spaceman) — prior art for window-management and Spaces SPI usage patterns.
- [movingpaper](https://github.com/8bittts/movingpaper) — pattern for the DMG build + notarization pipeline.
- Apple, for tolerating these private symbols on the platform for a very long time.
