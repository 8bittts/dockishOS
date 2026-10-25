# Foundation

History and the decision record for DockishOS; every other doc describes the code as it is.

## Timeline

Dates are the evidence in this doc; the owner docs carry none.

- 2026-04-17: the initial commit, the `Option-Space` launcher with fuzzy search, the `Option-Tab` switcher with the multi-hotkey `HotkeyManager`, per-window Accessibility raise and the Spaces switcher row over private CGS SPIs, per-monitor opt-out, and the Sparkle auto-update pipeline with a signed-feed appcast all land, and releases v0.002 through v0.013 ship the same day.
- 2026-04-18: `BUILD.md` records the build, sign and release procedure; it is now [05-infrastructure.md](05-infrastructure.md).
- 2026-04-19: app controls and the release flow are hardened and the release and local build flows are clarified.
- 2026-04-30: the switcher and badge handling are hardened and v0.014 and v0.015 ship.
- 0.014 to 0.020: the vendored Sparkle framework lost its `Updater.app` symlink, so in-app updates aborted with "Cannot retrieve path for auxiliary tool"; the pin in `tools/sparkle/VERSION` with its `required_paths` and the `verify_sparkle_vendor` build preflight came out of that regression ([05-infrastructure.md](05-infrastructure.md)).
- 0.027: the HIG and accessibility pass makes the bar reachable by VoiceOver and Full Keyboard Access, adds Previous Space and Next Space to the status menu, honors Reduce Motion and Reduce Transparency, and templates the menu-bar mark ([02-design-system.md](02-design-system.md)).

## Decisions

- **Current-Space only.** The bar shows what is open on this Space instead of every app on every desktop, and it never replaces or configures the system Dock.
- **Accessory app with no Dock icon.** `LSUIElement` keeps DockishOS out of the Dock; the status item and hotkeys are the entry points.
- **Accessibility permission on demand.** Window listing and Spaces switching work without Screen Recording, and Accessibility is requested only when a feature raises or closes a window or reads a Dock badge ([04-security.md](04-security.md)).
- **No CI.** The local gates are the only gates, so `swift test` and `./scripts/smoke-test.sh` run before every push ([09-quality.md](09-quality.md)).
- **The appcast is generated, never edited.** Its EdDSA signature covers the exact bytes, so every edit goes through `scripts/generate-appcast.sh` or the release flow.
- **This repository owns the Sparkle re-vendor procedure** for both macOS apps; MovingPaper cites it.
- **The backlog carries no risk registers or review archives.** Completed analysis lives in git history; `CHANGELOG.md` is the user-facing record.
