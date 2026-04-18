<p align="center">
  <img src="build/dockishos.png" alt="DockishOS" width="200">
</p>

<h1 align="center">DockishOS</h1>

<p align="center">
  A free, open-source Dock alternative for people who actually use macOS Spaces. Built from scratch with AppKit + SwiftUI, with a vendored Sparkle framework for signed updates. No analytics, no telemetry.
</p>

<p align="center">
  <!-- version-badge -->v0.011<!-- /version-badge --> · macOS 14+ · Swift 5.10+ · MIT
</p>

---

## Download

<!-- download-link -->
[**Download DockishOS v0.011**](https://github.com/8bittts/dockishOS/releases/download/v0.011/DockishOS-0.011.dmg)
<!-- /download-link -->

Open the `.dmg`, drag **DockishOS** to `/Applications`, launch it. Look for the floating bar on every enabled display (bottom edge by default) and the dock-shaped icon in the menu bar. Releases are code-signed with a Developer ID and notarized by Apple.

---

## What it does

DockishOS adds a translucent floating bar to every enabled display. Each bar shows:

1. **Pinned apps** *(optional)* — your favorites, drag-to-reorder, click to launch or activate.
2. **Windows** — every window on the *current* Space, not every running app.
3. **A collapse control** — the full-width bar slides offscreen and leaves a compact bottom-corner edge tab you can reopen.

When the pinned row is visible, matching apps are omitted from the windows row so you do not get duplicate Chrome, Slack, or Finder chips. Frontmost state is expressed through the chip treatment itself, not by a separate indicator light. Scroll vertically over the bar to switch Spaces on that display.

It is designed for people who use macOS Spaces heavily and find the default Dock unhelpful at telling them what's actually open right now.

> **Note:** DockishOS does not manage the system Dock. Configure Dock behavior in System Settings → Desktop & Dock.

---

## Quick start

```bash
git clone https://github.com/8bittts/dockishOS.git
cd dockishOS
./scripts/build_and_run.sh
```

The app launches as a menu-bar accessory (no Dock icon, no `Cmd+Tab` entry). Quit from the menu bar item → **Quit DockishOS**.

> **Tip:** DockishOS only prompts for Accessibility, and only on first window action. That prompt is intentionally one-shot across launches until access is granted or the user resets TCC. There is no Screen Recording prompt in the current build.

For the full build pipeline (signed DMG, notarization, Sparkle release), see the developer notes in `CLAUDE.md`.

---

## Topics

### Spaces

DockishOS keeps Space switching lightweight: there is no visible Spaces strip on the bar. Instead, scroll vertically anywhere over the bar to move to the previous or next Space on that display.

| Action | Result |
|---|---|
| Scroll vertically over the bar | Switch to previous / next Space (250 ms cooldown) |

DockishOS handles macOS's "Displays have separate Spaces" toggle in both states.

### Windows

Every window on the *current* Space is listed. Updates immediately on Space switch and app activation, with a backstop poll every second for newly-opened windows.

| Action | Result |
|---|---|
| Click chip | Activate the app **and** raise that specific window |
| Right-click → Activate / Close Window | Same as click / press the AX close button |
| Hover (instant) | Tooltip with the full window title |

**Group windows by app** (Settings → Appearance) collapses multiple windows of the same app to one chip with a count badge. Click cycles through them; right-click lists each window by title. If the pinned row is visible, pinned app bundles are filtered out of the windows row.

Hover stays lightweight on purpose: no floating thumbnail panel, no preview capture, no extra permission prompt.

> If macOS withholds a foreign-app window title, the chip falls back to the owning app's name (for example, "Safari" or "Terminal").

### Pinned apps

When enabled and non-empty, the pinned row sits at the leading edge of the bar before the windows row. Each chip shows the app icon and a small running-state dot.

| Action | Result |
|---|---|
| Click chip | Activate the app if running, otherwise launch it |
| Drag chip onto another | Reorder pins |
| Drag a `.app` from Finder onto the bar | Pin that app |
| Right-click → Move Left / Right / Unpin | Reorder or remove |

Pin a running app from the right-click menu of any window chip, or from the right-click menu of any launcher result.
Pinned apps also survive ordinary app moves or reinstalls when macOS can still resolve the bundle identifier to the current `.app` location.

### Settings

Open with **⌘,** or **Settings…** in the menu bar item.

| Tab | Controls |
|---|---|
| **Appearance** | Bar size (S / M / L), bar position (Top / Bottom), show window titles, show pinned row, group windows by app, show notification badges |
| **Behavior** | Customize launcher + switcher hotkeys, collapse bar into edge tab, choose the collapsed-tab side, launch at login, per-display opt-in/out |
| **Pinned** | Reorder or unpin individual apps |
| **About** | Version, build, links |

### Menu bar

A small dock-shaped icon in the menu bar exposes:

| Item | |
|---|---|
| Open Launcher | Same as the launcher hotkey |
| Settings… | ⌘, |
| Collapse Bar / Expand Bar | Toggle the edge-tab presentation |
| Collapsed Tab Position | Choose bottom-left or bottom-right |
| Open GitHub Repo | Opens the project page |
| Check for Updates… | Appears only in real `.app` installs with Sparkle available |
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

DockishOS checks for updates hourly via [Sparkle](https://sparkle-project.org) once installed from the DMG. The standard Sparkle dialog appears when a new release is available. Manual check via **Check for Updates…** in the menu bar item. The feed is served from the repository's tracked `appcast.xml`, and both the feed and DMG updates are EdDSA-signed; verification is enforced (`SUVerifyUpdateBeforeExtraction`, `SURequireSignedFeed`).

`swift run` builds skip Sparkle entirely — auto-update only takes effect inside a real `.app` bundle.

### Permissions

DockishOS requests permissions **lazily**, only on first use of a feature that needs them.

| Permission | Required for | Prompted on |
|---|---|---|
| Accessibility | Per-window raise + close, notification badges | First click on a window chip |

Spaces enumeration and switching require **no** permissions.

---

## Roadmap

The core DockishOS roadmap is complete. Per-display bars, per-window activation, scroll-to-switch Spaces, launcher, switcher, settings, pinned apps, drag/drop, customizable hotkeys, login item, signed DMG packaging, Sparkle auto-update, and opt-in notification badges all ship in the current release.

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
