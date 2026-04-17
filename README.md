# DockishOS

**A native macOS taskbar that organizes windows by Space.**

A free, open-source Dock alternative inspired by [boringBar](https://boringbar.app). Built from scratch with AppKit + SwiftUI, no third-party dependencies, no analytics, no telemetry.

[![macOS](https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](https://swift.org/package-manager/)
[![License](https://img.shields.io/github/license/8bittts/dockishOS)](LICENSE)

> **Status:** Early. Functional foundation: per-monitor floating bar, Spaces switcher, per-window raise. See [Roadmap](#roadmap).

---

## Overview

DockishOS replaces the macOS Dock with a translucent floating bar at the bottom of every display. Each bar shows:

- **Spaces row** — numbered chips for every virtual desktop on that display, current one highlighted, click to switch.
- **Windows row** — chips for every window on the *current* Space (not every running app), with the frontmost window outlined in your accent color. Click to raise the specific window.

It is designed for people who use macOS Spaces heavily and find the default Dock unhelpful at telling them what's actually open right now.

> **Note:** DockishOS does not hide the system Dock. Set System Settings → Desktop & Dock → "Automatically hide and show the Dock" yourself if you want it gone.

---

## Quick start

```bash
git clone https://github.com/8bittts/dockishOS.git
cd dockishOS
swift run DockishOS
```

The app launches as a menu-bar accessory (no Dock icon, no `Cmd+Tab` entry). A bar appears at the bottom of every connected display. Quit with `Ctrl+C` in the terminal.

> **Tip:** First click on a window chip will trigger the macOS Accessibility prompt. Grant it in System Settings → Privacy & Security → Accessibility, then re-launch DockishOS.

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

> **Note:** Without Screen Recording permission, foreign-app window titles are redacted by macOS to the empty string. The chip falls back to the owning app's name (e.g., "Safari", "Terminal"). With Screen Recording, you get titles like "Inbox - Mail" or "AppDelegate.swift — DockishOS".

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

### Commands

```bash
swift build                # Debug build → .build/debug/DockishOS
swift build -c release     # Release build → .build/release/DockishOS
swift run DockishOS        # Build + run
swift package clean        # Reset build artifacts
```

### Open in Xcode

```bash
open Package.swift
```

Xcode will read the SwiftPM manifest directly. There is no `.xcodeproj` checked in.

---

## Roadmap

Toward boringBar feature parity, in priority order:

- [x] Per-monitor floating bar
- [x] Current-Space window enumeration
- [x] Per-window AX raise + close
- [x] Spaces row with click-to-switch
- [x] Frontmost window indicator
- [x] Scroll wheel over bar to switch Spaces
- [x] Window thumbnails on hover (ScreenCaptureKit)
- [ ] App launcher with global hotkey
- [ ] Pinned apps row
- [ ] System Dock auto-hide toggle
- [ ] Notification badge counts
- [ ] Settings window (size, chip titles, per-monitor opt-in)
- [ ] Bundle as signed `.app` with proper `Info.plist`

---

## How DockishOS compares

| | DockishOS | macOS Dock | boringBar | Übersicht |
|---|---|---|---|---|
| Free / open source | ✓ | – | – ($30) | ✓ |
| Per-monitor bars | ✓ | – (one per primary) | ✓ | ✓ |
| Window list per Space | ✓ | – | ✓ | – |
| Spaces switcher in-bar | ✓ | – | ✓ | – |
| Window thumbnails | planned | ✓ (Mission Control) | ✓ | – |
| App launcher | planned | ✓ (apps only) | ✓ | – |

DockishOS is not trying to replace boringBar — boringBar is more polished, ships as a signed `.app`, has a paid support model. DockishOS exists to let people who want the same shape of UI do it for free, in source they can read and modify.

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

- [boringBar](https://boringbar.app) — the reference design and feature spec.
- [yabai](https://github.com/koekeishiya/yabai), [AltTab](https://github.com/lwouis/alt-tab-macos), [Spaceman](https://github.com/Jaysce/Spaceman) — prior art for SPI usage patterns.
- Apple, for tolerating these private symbols on the platform for a very long time.
