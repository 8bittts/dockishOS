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

#### Phase 1 — `activateNext` window round-robin fix (Candidate A.1)
- [x] Cycle over a stable window-ID order and track the last-activated `CGWindowID` per group instead of a positional index into the z-ordered list (`WindowStore.swift:95-107`). Builds clean.
- [ ] Manual verify: with "group windows by app" on, repeatedly clicking a 3-window app chip advances through all three windows in a fixed order (not just re-raising the frontmost).

### Follow-On Candidates
Not active work. Promote only one item at a time into `#### Phase N` in `### Work TODOs` when implementation starts.

Source: full-codebase audit (view/controller, data/store, system-integration layers), then adversarially re-verified against current source (one skeptic per finding + diverse-lens gap hunt). Every item below was confirmed at its stated file:line; severities reflect the re-verified impact, and several first-pass overstatements were corrected. Ranked within each group by impact.

#### Candidate A — Correctness bugs (verified; real behavior impact)
- [~] **`activateNext` cannot round-robin an app's windows.** — promoted to `#### Phase 1` (in progress).
- [ ] **Silent app-launch failure.** `LauncherStore` (`:75`) and `PinnedAppsStore.launch` (`:107`) call `NSWorkspace.shared.openApplication(...) { _, _ in }`, discarding the `Error?`. A cached/pinned app that was moved/deleted/quarantined fails with no launch, no beep, no `Diagnostics` log — undiagnosable. Fix: capture the error, log via `Diagnostics` + `NSSound.beep()`; optionally refresh the stale index entry.
- [ ] **AX calls on main thread can hang the UI.** `WindowControl.axWindow` (`WindowControl.swift:47-60`) and `raise`/`close` (`:34-42`) issue synchronous foreign-app AX messages with no `AXUIElementSetMessagingTimeout` (the only timeout in the tree is `BadgeStore.swift:81`). A hung target blocks the main run loop for the ~6s default AX timeout. Fix: set a small messaging timeout before traversal, or dispatch off-main.
- [ ] **Updater floats every DockishOS window that becomes key mid-update.** `Updater.startFloatingWindows` (`Updater.swift:79-87`) observes `didBecomeKeyNotification` with `object: nil`, so opening the launcher/Settings during an update transiently promotes it to `.floating` (reverted at teardown). Fix: filter the observer to Sparkle-owned windows.
- [ ] **SpacesStore fallback can silently disable scroll-to-switch-Spaces.** With ≥2 displays, `spaces(for:)` (`SpacesStore.swift:42`, lowest-index display) and `currentSpaceID(for:)` (`:47`, nondeterministic `values.first`) can resolve to different displays when a display UUID is absent; `BarController.handleVerticalScroll` (`:96`) then gets `firstIndex == nil` and the gesture no-ops. Fix: derive one display key and use it in both methods.

#### Candidate B — Concurrency & lifecycle (verified)
- [ ] **Off-main icon construction is a latent data race.** `LauncherStore.refreshIndex` (`:27-28`) runs `AppIndex.scan()` in `Task.detached`; scan builds `NSWorkspace.shared.icon(forFile:)` + `Bundle(url:).infoDictionary` per app (`AppIndex.swift:40,50`) off-main and returns non-Sendable `[AppEntry]` (each holding an `NSImage`) across the `@MainActor` boundary, while the same icon APIs run on main from view bodies (`PinnedRow.swift:71`, `SwitcherView.swift:87`). Swift-tools 5.10 without StrictConcurrency hides it. Fix: scan metadata off-main, materialize icons lazily on main (mirror `AppIconView`), or funnel icon creation onto one queue.
- [ ] **`PinnedAppsStore.load()` blocks main at launch.** Init runs via `BarController.init` on the main thread at launch → `load()` → `resolvedPinnedApp` calls synchronous `NSWorkspace.urlForApplication(withBundleIdentifier:)` (LaunchServices) + `fileExists` per pin (`PinnedAppsStore.swift:117,129,134`). Fix: render from persisted paths immediately, resolve/validate async, publish corrections on main.
- [ ] **`SwitcherController` Binding retains `self` strongly.** `SwitcherController.rebuildView` (`:77-78`) captures `self` (not `[weak self]`) in the `selectedIndex` Binding while sibling closures (`:80-81`) use `[weak self]`, forming a controller→hostingView→Binding→controller cycle. Masked only by the `.shared` singleton lifetime. Fix: `[weak self]` in both Binding closures.

#### Candidate C — Robustness / silent-failure diagnostics (low)
- [ ] **`HotkeyManager` ignores Carbon `OSStatus`.** `installHandlerIfNeeded` (`HotkeyManager.swift:96-125`) discards `InstallEventHandler` status (`handlerRef` left nil on failure) and `GetEventParameter` status (`:107-115`). Corrected: practically unreachable for a static `EventTypeSpec` + valid target, and it self-heals on the next `register()` (not a spin-loop) — so this is defensive logging, not a live bug. Fix: check both, log a `Diagnostics.lifecycle.fault`.
- [ ] **`WindowControl.raise`/`close` discard `AXError`.** `WindowControl.swift:34,35,42` ignore the AXError from the raise / set-main / press actions; a hung app or vanished window fails silently (raise can even bring the wrong window forward). Fix: log on non-`.success`.
- [ ] **`NSGradient` force-unwrap in the fallback icon path.** `DockishBrandAssets.swift:117` force-unwraps failable `NSGradient(starting:ending:)` inside the "everything else failed" degrade path. Fix: bind and fall back to a solid fill.

#### Candidate D — Performance (verified; severities corrected down)
- [ ] **`grouped()` recomputed ~3× per body & uncached.** `WindowChips` `visibleGroups` (`:24`) reads `WindowStore.grouped()` (`WindowStore.swift:69-91`, rebuilds id→window dict + `WindowGrouping.group`) from the `ForEach` (`:45`), the `isEmpty` check (`:46`), and `layoutAnimationKey` (`:31`); only fires when `groupWindowsByApp` is on. Fix: bind once into a `let` at top of `body`, or cache on the store when `windows` changes. (Low — window counts are small.) Note: the first-pass `SpacesStore.spaces(for:)` "sorts on every read" claim was wrong — that sort is a rare fallback path off a scroll handler, not a render path; dropped.
- [ ] **`SwitcherTile` resolves app icon per render.** `SwitcherView.swift:86-91` calls `NSRunningApplication(processIdentifier:).icon` every render/selection change. Fix: resolve once and cache.
- [ ] **(Low, optional) Redundant Spaces SPI on the 1s poll.** `WindowEnumerator.currentFullscreenSpaceIDs` (`:66-72`) runs `CGSCopyManagedDisplaySpaces` + per-display current-space probes every `currentSpaceWindows()` (1s, `WindowStore.swift:30`). Corrected: `SpacesStore`'s 5s cache excludes fullscreen (SPI `includeFullscreen` defaults false) so it can't be reused as-is, and the heavy per-space `windowIDs` loop is already guarded (`:50`). Redundancy nit, not an expensive path — only act if it profiles hot (short-TTL cache of fullscreen IDs).
- [ ] **(Low, optional) `runningApplications` dict rebuilt every 1s.** `WindowEnumerator.swift:27-32` allocates a pid→app map per poll for bundleIDs. Fix (optional): reuse a `RunningAppsStore` map — caveat: an event-driven map can briefly miss a just-launched app's bundleID; refresh on the same activation notification.
- [ ] **(Low, optional) Launcher scoring re-lowercases per keystroke.** `AppSearchScorer.swift:9,12` recompute `lowercased()`/`split` per candidate; scoring runs on main per `$query` (`LauncherStore.swift:19-22,41-44`). At ~hundreds of short names this is imperceptible. Fix (optional): precompute lowercased name + words on `AppEntry` at scan time. Do NOT add `.debounce` — it would only add latency to an instant local search.
- [ ] **(Low) Badge reader micro-opt.** `DockBadgeReader.read()` (`BadgeStore.swift:73`) linear-scans `runningApplications` and resolves bundleIDs via `Bundle(url:)` (`:116`) each 2.5s; `Bundle` is internally cached and the AX IPC to the Dock dominates, so gains are marginal. Same linear-scan in `PinnedAppsStore.runningApp(for:)` (`:32`).

#### Candidate E — De-duplication / refactor (verified; precision corrected)
- [ ] **`WindowChip` vs `WindowGroupChip`: ~90 duplicated lines.** `WindowChips.swift:116-224` vs `:226-353` (`chipFill`/`chipChrome`/`borderOpacity`/`topHighlightOpacity`/frontmost accent/hover). Extract a shared `ChipChrome` modifier. Align the stray `NotificationBadge` offset (`:134` `x:4` vs `:247` `x:6`).
- [ ] **`BarController` animate mirror duplication + one dead param.** `animateCollapse`/`animateExpand` (`:122-232`) are mirror images each recomputing frames 4×; consolidate to `animate(toCollapsed:)` + a geometry struct. `collapsedOriginX` (`:294-305`) has an unused `exposedWidth` param — remove it and the call-site arg (`:267`). Corrected: `collapsedOriginY`'s `exposedHeight` IS used (`:312`) — leave it.
- [ ] **`DisplayNameDisambiguator` stranded in the App target.** `ScreenItem.snapshot()` (`SettingsView.swift:166`) holds pure duplicate-name suffixing logic with no test. Extract to `DockishOSCore` + unit-test the no-collision / 2-way / 3-way cases (mirrors `AppSearchScorer`/`WindowGrouping`).
- [ ] **Shared collapsed-tab magic number.** `collapsedTabWidth = 56` (`BarController.swift:17`) duplicates `CollapsedTabMetrics.clusterWidth` (`BarView.swift:129`). Centralize. Corrected: "height 40 duplicated" and "make all metrics `static`" are false — `40` appears once and `clusterHeight` depends on `barSize`.
- [ ] **`CollapsedTabPosition` vs `CollapsedTabPlacement`.** Two two-case enums exist (`Settings.swift:14-44` vs Core) as a deliberate module split. Corrected: only the case list is duplicated — the persist/migration mapping already lives once in Core and Settings delegates to it (`isRightEdge` is not duplicated). Minor nit; optionally collapse the case duplication.
- [ ] **Selection-wrap duplication.** `(index + delta + count) % count` in `SwitcherView.advance` (`:66-70`) and `SwitcherController.advanceSelection` (`:66-71`). Consolidate to the controller.
- [ ] **App version read duplicated.** `CFBundleShortVersionString` lookup with `?? "dev"` in `SettingsView.swift:414` and `MenuBarController.swift:167`. Corrected: the build number is NOT duplicated (only in `AboutTab`). Extract an `AppVersion` helper for the version string.
- [ ] **Minor DI / consistency.** `BarView.handleFinderDrop` (`:109`) uses `PinnedAppsStore.shared` despite an injected `pinnedStore`; `BehaviorTab` defaults `settings` inline (`SettingsView.swift:71`). `MenuBarController` sets menu title/image in both Combine sinks (`:125-146`) and `menuNeedsUpdate` (`:181-188`). `LauncherController.resignObserver` (`:28-37`) never removed (singleton-safe).

#### Candidate F — Dead code (periphery-flagged; confirm each with `periphery scan` before deleting)
- [ ] `DockishBrandAssets.swift`: `menuBarIcon(size:)` (`6-15`) + `renderedTemplateFallbackIcon(size:)` (`66-101`) — no production caller (only the negative regression test references the name).
- [ ] `HotkeyManager.swift`: unlabeled `register(keyCode:modifiers:onFire:)` overload (`52-60`) — both call sites use the named form.
- [ ] `LauncherStore.swift`: `activateSelected()` (`60-64`) — `LauncherView` has its own private version.
- [ ] `PinnedAppsStore.swift`: `reorder(from:to:)` (`72-75`) + `icon(for:)` (`35-38`) — no callers.
- [ ] `Settings.swift`: `BarSize.spaceChipSize` (`83-89`); `BarSupport.swift`: `ChipStyle.inactiveOpacity`/`hoverOpacity`/`frontmostOpacity` (`60-62`); `BarView.swift`: unused `screen` property (`20`, drop the arg at `BarController.swift:36`); `Diagnostics.swift`: unused `bar` logger (`15`).
