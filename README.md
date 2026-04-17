# DockishOS

A macOS taskbar that organizes windows by Space — a from-scratch take inspired by [boringBar](https://boringbar.app), built with AppKit + SwiftUI.

## Status

**Foundation only.** A floating, translucent bar appears at the bottom of every connected display. It lists windows on the current Space and activates the owning app on click. No Spaces switcher, thumbnails, app launcher, or pinned apps yet — see roadmap.

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
| Accessibility | Optional today, required for window-focus + Spaces switching later | `AXUIElement` raise actions, private `CGS*` Spaces SPIs |
| Screen Recording | Optional today, required for full window titles + thumbnails | `kCGWindowName` of foreign-app windows, ScreenCaptureKit thumbnails |

Without Screen Recording, chips show the owning app name instead of the window title. Without Accessibility, click-to-activate brings the app forward but doesn't focus a specific window.

## Architecture

| File | Role |
|---|---|
| `main.swift` | Entry point. Sets accessory activation policy, runs the app. |
| `AppDelegate.swift` | Lifecycle. Observes screen + Space changes, owns one `BarController` per `NSScreen`. |
| `BarController.swift` | Per-screen bar window controller. Anchors to `screen.visibleFrame` bottom edge. |
| `BarPanel.swift` | Borderless `NSPanel` at `.statusBar` level with `.canJoinAllSpaces` + `.fullScreenAuxiliary`. |
| `BarView.swift` | SwiftUI bar UI: chips with app icons + window titles, hover state, scrollable. |
| `WindowEnumerator.swift` | `CGWindowListCopyWindowInfo` wrapper. On-screen + layer-0 == current Space. No private SPI. |
| `WindowStore.swift` | `ObservableObject` model. 1s timer + `activeSpaceDidChange` notification refresh. |
| `Permissions.swift` | Accessibility check/prompt helper. |

## Roadmap (toward boringBar parity)

1. **Per-window focus** — `AXUIElement` + `kAXRaiseAction` instead of just app activation.
2. **Spaces switcher** — Private `CGSCopyWorkspaces` / `CGSManagedDisplaySetCurrentSpace` for one-click jumps.
3. **Window thumbnails** — ScreenCaptureKit hover previews.
4. **App launcher** — Spotlight-style fuzzy search over `/Applications` with global hotkey (`MASShortcut`).
5. **Pinned apps** — UserDefaults pin list rendered alongside the windows row.
6. **Dock auto-hide toggle** — `defaults write com.apple.dock` helpers.
7. **Notification badges** — Badge counts from `NSApplication.dockTile` proxy.
8. **Settings window** — Bar size (S/M/L), chip titles on/off, monitor selection.
9. **Bundle as `.app`** — Move from `swift run` to a signed `.app` with proper `Info.plist` usage strings.

## Prior art worth studying

- [yabai](https://github.com/koekeishiya/yabai) — window-management SPI usage.
- [AltTab](https://github.com/lwouis/alt-tab-macos) — robust window enumeration across Spaces.
- [Übersicht](https://github.com/felixhageloh/uebersicht) — always-on overlay patterns.

## License

See [LICENSE](LICENSE).
