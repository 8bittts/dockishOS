# DockishOS

A macOS taskbar that organizes windows by Space — a from-scratch take inspired by [boringBar](https://boringbar.app), built with AppKit + SwiftUI.

## Status

A floating, translucent bar appears at the bottom of every connected display.

- **Spaces row** (left) — numbered chips for every Space on the bar's display, current one highlighted, click to switch.
- **Windows row** (right) — chips for every window on the current Space. Click to raise the specific window (not just the app). Right-click for Activate / Close. Frontmost window gets an accent ring.

No thumbnails, app launcher, pinned apps, or settings yet — see roadmap.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ / Swift 5.10+

## Run

```bash
swift run DockishOS
```

The app launches as a menu-bar accessory (no Dock icon). A floating bar appears at the bottom of each display. Quit with `Ctrl+C` in the terminal.

## Permissions

| Permission | Status | Used for |
|---|---|---|
| Accessibility | Required for per-window raise + close | `AXUIElement` raise / press close-button |
| Screen Recording | Optional, required for full window titles + (future) thumbnails | `kCGWindowName` of foreign-app windows, ScreenCaptureKit thumbnails |

The first time you click a window chip, macOS will prompt for Accessibility. Granting it enables true per-window focus; until then, clicks only bring the owning app forward. Spaces switching uses private CoreGraphics SPIs that don't require any permission grant.

Without Screen Recording, window chips show the app name instead of the window title.

## Architecture

| File | Role |
|---|---|
| `main.swift` | Entry point. Sets accessory activation policy, runs the app. |
| `AppDelegate.swift` | Lifecycle. Observes screen + Space changes, owns one `BarController` per `NSScreen`. |
| `BarController.swift` | Per-screen bar window controller. Anchors to `screen.visibleFrame` bottom edge. |
| `BarPanel.swift` | Borderless `NSPanel` at `.statusBar` level with `.canJoinAllSpaces` + `.fullScreenAuxiliary`. |
| `BarView.swift` | SwiftUI bar UI: Spaces chips on the left, windows on the right, hover + frontmost states. |
| `WindowEnumerator.swift` | `CGWindowListCopyWindowInfo` wrapper. On-screen + layer-0 == current Space. No private SPI. |
| `WindowStore.swift` | `ObservableObject` window model. 1s timer + `activeSpaceDidChange` + `didActivateApplication` refresh. |
| `WindowControl.swift` | AX-based window raise + close. Uses private `_AXUIElementGetWindow` to map CGWindowID → AX element. |
| `SpacesAPI.swift` | Private `CGS*` Spaces SPI bindings: enumerate, get current, switch. |
| `SpacesStore.swift` | `ObservableObject` Spaces model. Refreshes on `activeSpaceDidChange` + 5s polling. |
| `Permissions.swift` | Accessibility check/prompt helper. |

### Private API surface

Two private symbols, both stable for ~10 years across macOS releases and used by every comparable tool:

- `_AXUIElementGetWindow(AXUIElement, CGWindowID*)` — `ApplicationServices.framework`. Maps an AX window element to its CGWindowID so we can match what the user clicked.
- `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, `CGSManagedDisplayGetCurrentSpace`, `CGSManagedDisplaySetCurrentSpace` — `CoreGraphics.framework`. Spaces enumeration and switching.

Apple tolerates these but reserves the right to break them. Calls are wrapped in graceful fallbacks; SPI failure should never crash the bar.

## Roadmap (toward boringBar parity)

- [x] Per-window focus via `AXUIElement` + `kAXRaiseAction`.
- [x] Spaces switcher via private `CGS*` SPIs.
- [ ] Window thumbnails (ScreenCaptureKit hover previews).
- [ ] App launcher (Spotlight-style fuzzy search over `/Applications`, global hotkey via `MASShortcut`).
- [ ] Pinned apps row backed by UserDefaults.
- [ ] Dock auto-hide toggle (`defaults write com.apple.dock`).
- [ ] Notification badges from `NSApplication.dockTile` proxies.
- [ ] Settings window (bar size, chip titles, per-monitor opt-in).
- [ ] Scroll-to-switch Spaces (already a BoringBar feature).
- [ ] Bundle as signed `.app` with proper `Info.plist` usage strings.

## Prior art worth studying

- [yabai](https://github.com/koekeishiya/yabai) — window-management SPI usage.
- [AltTab](https://github.com/lwouis/alt-tab-macos) — robust window enumeration across Spaces.
- [Übersicht](https://github.com/felixhageloh/uebersicht) — always-on overlay patterns.

## License

See [LICENSE](LICENSE).
