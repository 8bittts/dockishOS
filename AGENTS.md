# DockishOS agent notes

## Orientation

SwiftPM macOS 14+ menu-bar app (`Package.swift`): `DockishOSCore` is the AppKit/Carbon-free testable target, `DockishOS` is the app.
Validate with `swift build` and `swift test`; `./scripts/build-dmg.sh --build-only` assembles the `.app` without a DMG.
`./scripts/smoke-test.sh` runs the tests and verifies any built release artifacts; `--production` makes the signing, notarization, and appcast checks fail rather than warn.
There is no CI, so these local gates are the only gates.

[_docs/05-infrastructure.md](_docs/05-infrastructure.md) is authoritative for every build, sign, notarize, release, and Sparkle-vendoring procedure — read it before touching `scripts/`.
Owner-doc index: [_docs/00-docs-map.md](_docs/00-docs-map.md).
[README.md](README.md) and [docs/index.md](docs/index.md) are user-facing; update them when shipped behavior or developer workflow changes.

## Sparkle vendoring

A wrong `tools/sparkle/Sparkle.framework` fails in-app updates with the generic "An error occurred while launching the installer."
Upgrade only via `_docs/05-infrastructure.md` "Upgrading the Sparkle framework"; `./scripts/build-dmg.sh --build-only` is the fastest way to catch a bad vendor.

## Release caveats

[CRITICAL] Never hand-edit root `appcast.xml` — its embedded Sparkle EdDSA signature covers the file's exact byte length, so any edit fails every user's Check-for-Updates with "The update feed is improperly signed and could not be validated".
Regenerate and re-sign with `scripts/generate-appcast.sh` or the release flow; see `_docs/05-infrastructure.md` "Safety".

A `scripts/release-dockishOS.sh` failure at the appcast poll step alone does not mean the release failed; check `git log` and the GitHub release page before re-running anything.
The propagation delays behind that rule are in `_docs/05-infrastructure.md` "Appcast propagation".

## Backlog

In `_docs/todos.md`, do not re-add compatibility risk registers, review archives, or "pruned for over-engineering" parking lots; completed analysis belongs in git history.
