# DockishOS

**A native macOS taskbar that organizes windows by Space.**

A free, open-source Dock alternative for people who actually use macOS Spaces. Built from scratch with AppKit + SwiftUI, no third-party dependencies, no analytics, no telemetry.

<!-- version-badge -->v0.008<!-- /version-badge --> · macOS 14+ · Swift 5.10+ · MIT

[![macOS](https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](https://swift.org/package-manager/)
[![License](https://img.shields.io/github/license/8bittts/dockishOS)](LICENSE)

---

## Download

<!-- download-link -->
[**Download DockishOS v0.008**](https://github.com/8bittts/dockishOS/releases/download/v0.008/DockishOS-0.008.dmg)
<!-- /download-link -->

Open the `.dmg`, drag **DockishOS** to `/Applications`, launch it. Look for the floating bar at the bottom of every display and the dock-shaped icon in the menu bar. Releases are code-signed with a Developer ID and notarized by Apple.

---

## What it does

DockishOS adds a translucent floating bar to every display. Each bar shows three rows side-by-side:

1. **Spaces** — numbered chips for the virtual desktops on this display, current one highlighted, click to switch.
2. **Pinned apps** *(optional)* — your favorites, drag-to-reorder, click to launch / activate.
3. **Windows** — every window on the *current* Space (not every running app), with the frontmost outlined in your accent color.

It is designed for people who use macOS Spaces heavily and find the default Dock unhelpful at telling them what's actually open right now.

> **Note:** DockishOS does not hide the system Dock. Toggle System Settings → Desktop & Dock → "Automatically hide and show the Dock" yourself, or use the menu-bar item's **Auto-hide system Dock** entry.

---

## Quick start

```bash
git clone https://github.com/8bittts/dockishOS.git
cd dockishOS
./scripts/build_and_run.sh
```

The app launches as a menu-bar accessory (no Dock icon, no `Cmd+Tab` entry). Quit from the menu bar item → **Quit DockishOS**.

> **Tip:** First click on a window chip prompts for Accessibility. First 200 ms hover prompts for Screen Recording. Grant both in System Settings → Privacy & Security, then re-launch.

For the full build pipeline (signed DMG, notarization, Sparkle release), see the developer notes in `CLAUDE.md`.

---

## Topics

### Spaces

The leftmost section of every bar shows the Spaces (virtual desktops) on the bar's display. Current Space is solid white; others are translucent.

| Action | Result |
|---|---|
| Click chip `N` | Switch to Space N on this display |
| Scroll vertically over the bar | Switch to previous / next Space (250 ms cooldown) |

DockishOS handles macOS's "Displays have separate Spaces" toggle in both states.

### Windows

Every window on the *current* Space is listed. Updates immediately on Space switch and app activation; backstop poll every second for newly-opened windows.

| Action | Result |
|---|---|
| Click chip | Activate the app **and** raise that specific window |
| Right-click → Activate / Close Window | Same as click / press the AX close button |
| Hover (200 ms) | Floating thumbnail preview via ScreenCaptureKit |
| Hover (instant) | Tooltip with the full window title |

**Group windows by app** (Settings → Appearance) collapses multiple windows of the same app to one chip with a count badge. Click cycles through them; right-click lists each window by title.

> Without Screen Recording permission, foreign-app titles redact to the empty string and the chip falls back to the owning app's name (e.g., "Safari", "Terminal").

### Pinned apps

A row of pinned-app chips lives between Spaces and Windows. Each chip shows the app's icon and a small running-state dot.

| Action | Result |
|---|---|
| Click chip | Activate the app if running, otherwise launch it |
| Drag chip onto another | Reorder pins |
| Drag a `.app` from Finder onto the bar | Pin that app |
| Right-click → Move Left / Right / Unpin | Reorder or remove |

Pin a running app from the right-click menu of any window chip, or from the right-click menu of any launcher result.

### Settings

Open with **⌘,** or **Settings…** in the menu bar item.

| Tab | Controls |
|---|---|
| **Appearance** | Bar size (S / M / L), bar position (Top / Bottom), show window titles, show pinned row, group windows by app, show notification badges |
| **Behavior** | Customize launcher + switcher hotkeys, auto-hide system Dock, launch at login, per-display opt-in/out |
| **Pinned** | Reorder or unpin individual apps |
| **About** | Version, build, links |

### Menu bar

A small dock-shaped icon in the menu bar exposes:

| Item | |
|---|---|
| Open Launcher | Same as the launcher hotkey |
| Settings… | ⌘, |
| Auto-hide system Dock | Toggle macOS Dock auto-hide (state shown by checkmark) |
| Open GitHub Repo | Opens the project page |
| Quit DockishOS | ⌘Q |

### Launcher

**⌥ Space** by default. Type to fuzzy-search every `.app` in `/Applications`, `/System/Applications`, and `~/Applications`.

| Action | Key |
|---|---|
| Toggle | ⌥ Space *(configurable)* |
| Move selection | ↑ / ↓ |
| Launch | Return |
| Dismiss | Esc / click outside |

### App switcher

**⌥ Tab** by default. Horizontal grid of every window on the current Space — a Cmd+Tab replacement that respects Spaces.

| Action | Key |
|---|---|
| Toggle | ⌥ Tab *(configurable)* |
| Cycle selection | Tab, →, ← |
| Activate | Return |
| Dismiss | Esc / click outside |

### Notification badges *(opt-in)*

Settings → Appearance → **Show notification badges** reads each app's badge string from the macOS Dock's accessibility tree every 2.5 s and overlays a small red badge on the matching chip. Default off because it relies on an undocumented Dock attribute (`AXStatusLabel`) that may break in future macOS releases — see `CLAUDE.md` for details.

### Auto-update

DockishOS checks for updates hourly via [Sparkle](https://sparkle-project.org) once installed from the DMG. The standard Sparkle dialog appears when a new release is available. Manual check via **Check for Updates…** in the menu bar item. The appcast and updates are EdDSA-signed; verification is enforced (`SUVerifyUpdateBeforeExtraction`, `SURequireSignedFeed`).

`swift run` builds skip Sparkle entirely — auto-update only takes effect inside a real `.app` bundle.

### Permissions

DockishOS requests permissions **lazily**, only on first use of a feature that needs them.

| Permission | Required for | Prompted on |
|---|---|---|
| Accessibility | Per-window raise + close, notification badges | First click on a window chip |
| Screen Recording | Window titles + hover thumbnails | First 200 ms hover on a window chip |

Spaces enumeration and switching require **no** permissions.

---

## Roadmap

The original 25-item roadmap is complete. Everything DockishOS set out to do — per-monitor bars, per-window AX raise, Spaces switcher, hover thumbnails, app launcher, app switcher, settings, pinned apps, drag/drop, customizable hotkeys, login item, signed-DMG release pipeline, signed-feed Sparkle auto-update, opt-in notification badges — ships in the current release.

Future ideas live in [GitHub issues](https://github.com/8bittts/dockishOS/issues).

---

## Contributing

Issues and pull requests welcome. Ground rules:

- **Native APIs first.** Reach for `AXUIElement` / `CGS*` / Carbon `RegisterEventHotKey` before pulling in dependencies.
- **Main thread for UI + AX + CGS.** No background queues touching SwiftUI, AppKit, Accessibility, or Core Graphics Services.
- **No telemetry.** Not now, not ever.
- **Lazy permission prompts.** New features that need a TCC permission must prompt on first use, not at launch.
- **Run `swift build` clean.** No warnings, no broken SPI calls.

Architecture, file ownership, build scripts, the private-SPI inventory, and project-local engineering rules live in [`CLAUDE.md`](CLAUDE.md). Read it before opening a PR that touches the bar, the build pipeline, or any of the SPI bindings.

---

## License

[MIT](LICENSE) © 2026 [@8bittts](https://github.com/8bittts)

---

## Acknowledgments

- [yabai](https://github.com/koekeishiya/yabai), [AltTab](https://github.com/lwouis/alt-tab-macos), [Spaceman](https://github.com/Jaysce/Spaceman) — prior art for window-management and Spaces SPI usage.
- [movingpaper](https://github.com/8bittts/movingpaper) — pattern for the DMG build, notarization, and Sparkle release pipeline.
- Apple, for tolerating these private symbols on the platform for a very long time.
