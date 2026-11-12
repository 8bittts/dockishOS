# Quality

Gates, test strategy and verification rules for DockishOS.

## Gates

`swift build` and `swift test` validate the package; the unit suite in `Tests/DockishOSCoreTests` covers the `DockishOSCore` target.
`./scripts/smoke-test.sh` runs the tests, builds, and checks the bundle shape; when a release build is present it also verifies the signature, notarization ticket, checksum and signed appcast, and `--production` makes those checks fail rather than warn.
It fails closed: an absent artifact, an empty test run, a missing stapled notarization ticket, a checksum mismatch, or an appcast whose EdDSA signature does not verify is an error, never a silent pass.
There is no CI, so these local gates are the only gates; run them before every push.
`swift build --build-tests && periphery scan` reads `.periphery.yml` and must report no unused code; the build comes first because the config pins the index store and skips Periphery's own build.
Periphery exits 0 even when it reports unused code, so the pass is its `* No unused code detected.` line, never the exit code; a scan after a source edit without a fresh `--build-tests` build reads the old index and reports code that is already gone.
`CaskBumpTests` runs `bump_cask` on a copy of the real Cask and proves the release script calls it before the release commit.
`CommitMsgHookTests` runs `.githooks/commit-msg` against sample messages, so the hook that refuses AI attribution stays executable and fails closed; `./scripts/setup-hooks.sh` wires it once per clone.
`./scripts/build-dmg.sh --build-only` is the fastest way to catch a bad Sparkle vendor, because its preflight verifies the pinned framework.

## Test strategy

Logic that can be tested without AppKit or Carbon lives in `DockishOSCore` (geometry, selection wrap, reordering, grouping) so `swift test` covers it directly.
`HIGAccessibilityRegressionTests` pins the accessibility contracts in [02-design-system.md](02-design-system.md), `PanelRegressionTests` the switcher panel contracts, `HIGChromeRegressionTests` the icon mask, Settings window buttons, badge color, the glass-only surface and the macOS 27 minimum, `HIGWritingRegressionTests` the pin and unpin wording, shortcut warning, empty-state and untitled-window copy and the text-style rule, and `MenuBarIconRegressionTests` the template status mark.
These five suites read source text, so they live in the core test target without importing AppKit.
They hold a fix in place but cannot find a new defect: the switcher, focus, the status menu and the glass surfaces are only proven by driving a built bundle and looking at it.
Use `./scripts/build_and_run.sh` for anything involving Accessibility, login items, app metadata, icons or updates, because a plain `swift run` process behaves differently.

## Traps

After `./scripts/build-dmg.sh --build-only`, `build/DockishOS.app` exists without its DMG, so the default `smoke-test.sh` run treats it as a release build and demands the missing artifacts; remove the bundle or rebuild the DMG before running the smoke test.
`./scripts/build_and_run.sh` quits any running DockishOS before it launches the new build, and the build reads the same preferences as an installed copy.
A state the test Mac cannot reach, such as the dark appearance, a missing Accessibility permission or a second display, is checked by forcing it with a temporary uncommitted edit, capturing the result, and reverting the edit before any commit.
A bundle launched from a script starts in the background, where AppKit can report the app as active while another app is frontmost; test focus behavior from that state as well as after a normal launch.
A `scripts/release-dockishOS.sh` failure at the appcast poll step alone does not mean the release failed; check `git log` and the GitHub release page before re-running anything ([05-infrastructure.md](05-infrastructure.md)).

## Manual verification

- Confirm the bar on every enabled display, the collapse into the edge tab, and scroll-to-switch.
- Change Size, Position and Corner with the bar expanded and collapsed: the bottom bar and the edge tab slide through the bottom edge, the top bar fades in place, and nothing flickers or reopens.
- Open the switcher with `Option-Tab`: confirm Tab, Shift-Tab and the arrow keys move the selection, Return raises the selected window, and Escape or a click elsewhere closes it with the previous app still active.
- Change the shortcut in Settings and confirm the new binding.
- Open each Settings pane and confirm the window fits the pane and takes its name, and that Settings reopens on the last pane after a relaunch; then open About DockishOS from the status menu.
- Look at the bar, the edge tab and the switcher over light and dark content, in light and dark appearance.
- Open the status menu and confirm it lists About DockishOS, YEN Terminal, Settings…, GitHub Project, Check for Updates… and Quit DockishOS, and that YEN Terminal opens https://yen.chat.
- Trigger a window raise or close to confirm the Accessibility prompt appears only then.
- Check VoiceOver reach on the chips and the Reduce Motion and Reduce Transparency variants.
