# DockishOS TODOs

---
## MUST FOLLOW RULES and PROTOCOLS:
1. Never remove, delete, or modify this list unless directed to do so.
2. Active work only. Completed work lives in git history.
3. This is the ONLY TODO/backlog file.
4. Keep clear separation of concerns with phase-based checklists and zero task duplication.
5. Validate, review, and test each phase before moving to the next phase.
6. Stage and commit only files touched for the active phase. Ignore unrelated edits from other agents.
7. Review and update local `CLAUDE.md` / `AGENTS.md` only when those files exist or when a finding will materially help future agents; these files are gitignored local notes.
8. Update `README.md` / `BUILD.md` when user-facing behavior or developer workflow changes. Re-run signing/notarization only for release, packaging, entitlement, or distribution changes.

---
## BACKLOG

### Work TODOs

Promote exactly one Phase into active work at a time. Phase ordering is intentional.

#### Phase 1 — Product conversion (High)
- [ ] **Ship a hero screenshot + one GIF above the Features list.** `public/` contains only the DMG background (`mario.jpg`); the only README image is the 160px app icon. Shoot one screenshot of the bar on a real desktop with chips + one 3-5s GIF showing scroll-to-switch-Space and edge-tab collapse. Drop both above "Features" in `README.md`.

### Follow-On Candidates
Not active work. Promote only one item at a time into `#### Phase N` in `### Work TODOs` when implementation starts.

#### Medium complexity
- Move `Sources/DockishOS/AppIndex.scan()` off the main thread (`LauncherStore.swift:16-21`, `LauncherController.swift:53`) — cold scan of `/Applications` blocks the launcher open animation 50-150ms on a developer machine. Background actor + stale-snapshot UI.
- Replace `WindowStore.refresh()` polling with notification-driven refresh + throttled coalescing. Promote only after profiling shows idle polling is a user-visible cost; don't build a visibility coordinator preemptively.
- Delete `Sources/DockishOS/DockHelper.swift` — verified dead code (no call sites in the tree). Ships `Process` + `killall Dock` attack surface for zero benefit. If Dock auto-hide integration is ever wanted, design it fresh at that point.
- Harden `Sources/DockishOS/BadgeStore.swift:80-101` to search Dock AX children by `kAXRoleAttribute == kAXListRole` instead of `dockChildren.first` — Sonoma/Sequoia add `AXGroup`s whose ordering has changed.
- Make `Sources/DockishOS/SpacesStore.swift:50-54` `switchTo` verify the CGS set landed — re-query `currentSpaceID(for:)` on the next main-loop tick (or await `activeSpaceDidChange`) before mutating `currentByDisplay`.
- Tighten chip visual hierarchy: frontmost chip should carry `.bold` or a 2pt accent leading stripe in addition to opacity delta (`Sources/DockishOS/BarSupport.swift:61-63`).
- Replace `Color.white.opacity(…)` constants across `BarView.swift`, `WindowChips.swift`, `SwitcherView.swift` with semantic colors (`NSColor.separatorColor`, `.selectedContentBackgroundColor`, `.controlAccentColor`) so light-mode + high-contrast-mode users get usable affordances.
- Add Sparkle vendored-framework version pin (`tools/sparkle/VERSION` + checksum) and document the upgrade procedure in `BUILD.md`.
- Expand `Tests/DockishOSCoreTests/` — currently covers only 2 pure helpers out of ~4200 lines. Move `LauncherHotkey.carbonMask` mapping, `CollapsedTabPosition` migration, Settings JSON round-trip, and WindowStore grouping into `DockishOSCore` and add XCTests.
- Ship a `.github/FUNDING.yml` + a small GitHub Pages landing at `8bittts.github.io/dockishOS` (hero GIF + download CTA + 3-line pitch).
- Add `brew install --cask dockishos` path once the next notarized release is out; PR to `homebrew/homebrew-cask`.
- Fix Shift-Tab reverse cycling in switcher (`Sources/DockishOS/SwitcherView.swift:59`); currently Tab always advances forward, breaking the 30-year macOS convention.
- Add `--help` / `-h` parsing to all scripts; `scripts/build-dmg.sh:43-50` currently exits 1 on `--help` with "Unknown flag".

#### Higher complexity
(No items. Re-add only when a concrete user-facing driver exists.)

---
## REMINDERS
- [ ] If the product's brand position ever hardens, consider renaming from "DockishOS" (reads as an operating-system distro) to "Dockish" — keeps the repo name for continuity but removes the OS-name confusion for SEO / word-of-mouth. Deferred: don't touch bundle ID or Sparkle feed URL casually; breaking `SUFeedURL` continuity requires a migration release.
- [ ] Grow the `appcast.xml` archive to a rolling window (last 5 versions) with `generate_appcast --maximum-versions 5` — required if Sparkle delta updates are ever enabled; harmless noop if not.

---
## COMPATIBILITY RISK REGISTER
Snapshot from the Private-API review. Validate empirically before each macOS major-version bump.

| Feature | Private API | macOS 14 | macOS 15 | macOS 16 (likely) | Mitigation |
|---|---|---|---|---|---|
| Spaces enumeration | `CGSCopyManagedDisplaySpaces` | Works | Works | Likely works (`type==4` key has survived 10.7→15) | Degrade to an empty/single-space list on nil; log empty-result telemetry |
| Active-space read/write | `CGSManagedDisplayGetCurrentSpace` / `SetCurrentSpace` | Works | Works | At risk if Mission Control is replaced | Wrap no-throw callers; use `NSWorkspace.activeSpaceDidChangeNotification` as the read refresh source |
| CGWindowID to AXUIElement bridge | `_AXUIElementGetWindow` | Works | Works | Stable 15+ years | `dlsym` fallback in place; no title-match fallback |
| Per-window raise | `kAXRaiseAction` + `kAXMainAttribute` | Works | Works with modern activation first | Likely works | Modern activation helper in place on macOS 14+ |
| Per-window close | `kAXCloseButtonAttribute` + `kAXPressAction` | Works for standard windows | Same; fails on sheets/fullscreen | Same caveats | Detect subrole before expanding close behavior beyond standard windows |
| Global hotkeys | Carbon `RegisterEventHotKey` | Works | Works | Deprecated-but-working | Keep Carbon; registration failures now surface in the menu bar item |
| Accessibility trust | `AXIsProcessTrustedWithOptions` | Works | Works | Works | Recheck on demand; Settings opens Privacy & Security -> Accessibility |
| Dock badge read | AX tree `AXStatusLabel` | Works | Works | Highest churn risk of this set | Feature flag is off by default; AX messaging timeout is in place |
| Display UUID for screen | `CGDisplayCreateUUIDFromDisplayID` | Works | Deprecated-but-works | Likely removed | Use `NSScreen.displayID` on macOS 15+ when this becomes a real blocker |
| Login item | `SMAppService.mainApp.register` | Works | Works | Works | Modern API; no action |

---
## NOTES FROM 8-AGENT REVIEW (2026-04-19)
Devil's advocate filtered these claims out; keep them out unless a concrete driver appears:
- **Sparkle entitlements / library-validation** — repo already signs Sparkle.framework with the same Team ID (`GRNGR33Z8A`) + hardened runtime; Sparkle 2.x explicitly doesn't need `com.apple.security.cs.disable-library-validation` in this setup.
- **Sparkle feed URL on raw.githubusercontent.com** — `SURequireSignedFeed=true` + `SUPublicEDKey` make a compromised CDN non-exploitable; stylistic concern only.
- **`NSRunningApplication.activate(options:)` deprecation** — not actually deprecated on macOS 14/15; only "non-preferred." Behavior concern was handled with the activation helper.
- **`AXIsProcessTrustedWithOptions(prompt: true)` blocks main thread** — returns synchronously; OS prompt is async.
- **`as!` cast in `AXHelper.swift:32`** — guarded by `CFGetTypeID` check above; idiomatic CF bridging.
- **Launcher `.onKeyPress` only fires when field has focus** — attached to the outermost VStack, not the text field.
- **README has no screenshot** — it references `build/dockishos.png`, but this is the app icon, not a product screenshot; the real remaining item is the hero screenshot/GIF.

---
## PRUNED FOR OVER-ENGINEERING (2026-04-19)
Second-pass review removed items that added speculative surface area, anticipated hypothetical future requirements, or bundled correctness fixes with opportunistic refactors. Keep these out unless a concrete driver emerges.

- **Harden Carbon hotkey singleton lifetime.** `static let shared` guarantees lifetime. Pure defensive coding.
- **Title-match heuristic fallback for `_AXUIElementGetWindow`.** Symbol has been stable 15+ years. `dlsym` on its own is enough; the heuristic is code-for-the-sake-of-it.
- **`hdiutil attach -plist` + PlistBuddy rewrite.** The underlying bug was stderr being swallowed; the direct stderr fix is in place.
- **Accumulating `_cleanup_paths=()` trap framework.** Two temp files in the release script did not justify a framework; a single cleanup trap is enough.
- **Bundling poll-pause with notification-driven refresh as one Critical item.** The direct AX timeout is in place; notification replacement stays a follow-on until profiling shows a user-visible idle cost.
- **SwiftUI `Settings {}` scene migration.** `.resizable` plus removing the fixed SwiftUI frame was the surgical fix. A scene migration is a separate project.
- **`DockHelper.swift` migration from `killall Dock` to CFPreferences.** The file is dead code — delete it, don't migrate.
- **Unify Store/Controller/View patterns across modules.** Consistency-for-consistency refactor with no driving bug.
- **Convert `NSHostingView` to `NSHostingController` for Launcher/Switcher.** `@FocusState` works fine; menu validation doesn't apply to borderless panels.
- **`AppEnvironment` singleton-graph refactor.** Large refactor for speculative test ergonomics.
- **Diff-by-screen-UUID `rebuildBars()` reconcile.** State is rehydrated from `SettingsStore`; hotplug preservation was not a real driver.
- **Version-scheme migration to SemVer.** Current `M.NNN` works and avoids Sparkle comparison churn.
- **URL-scheme / CLI / XPC control surface.** Proactive API design with no user request. Add when someone asks for Keyboard Maestro / Raycast integration.
- **Homebrew Cask release-automation.** Ship one Cask manually first; automate only if manual submission becomes tedious.
- **Distributed Accessibility grant listener.** `ensureAccessibility()` rechecks `AXIsProcessTrusted()` on every raise/close attempt; the Settings status/button covers the user-visible need.
- **macOS 13 activation fallback.** Package minimum is macOS 14, so compatibility branches for 13 add dead code.
- **Visibility coordinator for all background pollers.** The repo has no measured idle-polling problem; keep the direct AX timeout fix and revisit polling only with measurements.
- **NSToolbar wrapper for Settings.** Resizing and removing the fixed SwiftUI frame addressed clipping without a navigation redesign.
- **Collapsible README feature sections.** Current README is short; collapsible sections would hide useful product detail without solving a real length problem.
