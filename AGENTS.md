# DockishOS agent notes

## Orientation

SwiftPM macOS 14+ menu-bar app (`Package.swift`): `DockishOSCore` is the AppKit/Carbon-free testable target, `DockishOS` is the app.
Validate with `swift build` and `swift test`; `./scripts/build-dmg.sh --build-only` assembles the `.app` without a DMG.
There is no CI, so these local gates are the only gates.

[BUILD.md](BUILD.md) is authoritative for every build, sign, notarize, release, and Sparkle-vendoring procedure — read it before touching `scripts/`.
Owner-doc index: [_docs/00-docs-map.md](_docs/00-docs-map.md).
[README.md](README.md) and [docs/index.md](docs/index.md) are user-facing; update them when shipped behavior or developer workflow changes.

## Sparkle vendoring

A wrong `tools/sparkle/Sparkle.framework` fails in-app updates with the generic "An error occurred while launching the installer."
Upgrade only via BUILD.md's "Upgrading the Sparkle framework"; `./scripts/build-dmg.sh --build-only` is the fastest way to catch a bad vendor.

## Release caveats

[CRITICAL] Never hand-edit root `appcast.xml` — its embedded Sparkle EdDSA signature covers the file's exact byte length, so any edit fails every user's Check-for-Updates with "The update feed is improperly signed and could not be validated".
Regenerate and re-sign with `scripts/generate-appcast.sh` or the release flow; see BUILD.md "Safety".

`scripts/release-dockishOS.sh` polls the live appcast for ~30s (10 attempts, 3s apart) and raw.githubusercontent.com's CDN can take longer to invalidate.
A failure at that step alone does not mean the release failed — check `git log` and the GitHub release page before re-running anything.

The live appcast is served with `cache-control: max-age=300`, which Sparkle's `URLCache.shared` honors.
An interactive Check-for-Updates can therefore report a stale "you're up to date" for up to 5 minutes after a release; the feed URL is deliberately not cache-busted.

## Backlog

In `todos.md`, do not re-add compatibility risk registers, review archives, or "pruned for over-engineering" parking lots; completed analysis belongs in git history.
