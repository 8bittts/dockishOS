# Quality

Gates, test strategy and verification rules for DockishOS.

## Gates

`swift build` and `swift test` validate the package; the unit suite in `Tests/DockishOSCoreTests` covers the `DockishOSCore` target.
`./scripts/smoke-test.sh` runs the tests, builds, and checks the bundle shape; when a release build is present it also verifies the signature, notarization ticket, checksum and signed appcast, and `--production` makes those checks fail rather than warn.
It fails closed: an absent artifact, an empty test run, a missing stapled notarization ticket, a checksum mismatch, or an appcast whose EdDSA signature does not verify is an error, never a silent pass.
There is no CI, so these local gates are the only gates; run them before every push.
`./scripts/build-dmg.sh --build-only` is the fastest way to catch a bad Sparkle vendor, because its preflight verifies the pinned framework.

## Test strategy

Logic that can be tested without AppKit or Carbon lives in `DockishOSCore` (search scoring, geometry, selection wrap, reordering, grouping) so `swift test` covers it directly.
`HIGAccessibilityRegressionTests` pins the accessibility contracts in [02-design-system.md](02-design-system.md), `HIGChromeRegressionTests` the icon mask, Settings window buttons and badge color, `HIGWritingRegressionTests` the pin and unpin wording, hotkey warning and untitled-window copy, and `MenuBarIconRegressionTests` the template status mark.
These four suites read source text, so they live in the core test target without importing AppKit.
Use `./scripts/build_and_run.sh` for anything involving Accessibility, login items, app metadata, icons or updates, because a plain `swift run` process behaves differently.

## Traps

After `./scripts/build-dmg.sh --build-only`, `build/DockishOS.app` exists without its DMG, so the default `smoke-test.sh` run treats it as a release build and demands the missing artifacts; remove the bundle or rebuild the DMG before running the smoke test.
A `scripts/release-dockishOS.sh` failure at the appcast poll step alone does not mean the release failed; check `git log` and the GitHub release page before re-running anything ([05-infrastructure.md](05-infrastructure.md)).

## Manual verification

- Confirm the bar on every enabled display, the collapse into the edge tab, and scroll-to-switch or the status-menu Space commands.
- Open the launcher with `Option-Space` and the switcher with `Option-Tab`, then change both hotkeys in Settings and confirm the new bindings.
- Trigger a window raise or close to confirm the Accessibility prompt appears only then.
- Check VoiceOver reach on the chips and the Reduce Motion and Reduce Transparency variants.
