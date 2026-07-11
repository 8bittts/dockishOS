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

(No active phase. One manual check is still pending from the last batch — see below.)

- [ ] **Manual verify (needs the running GUI app):** with "group windows by app" on, repeatedly clicking a 3-window app chip advances through all three windows in a fixed order (validates the shipped `activateNext` round-robin fix).

### Follow-On Candidates
Not active work. Promote only one item at a time into `#### Phase N` in `### Work TODOs` when implementation starts.

Source: full-codebase audit, adversarially re-verified against source, then implemented in batches. **Candidates A, C, F, the whole of the concurrency retain-cycle/off-main work, and the selection-wrap / app-version / grouped()-cache / DisplayNameDisambiguator / dead-param / injected-store refactors are shipped** — see git history (`9aa1cd4`, `d2c7897`, `61af2da`, `d29516e`, `b88fef6`, plus the injected-store fix). The items below are what remains: deliberately deferred as either optional micro-opts or larger refactors that warrant a focused pass with visual/behavioral verification.

#### Remaining — larger refactors (need visual/behavioral verification)
- [x] **`WindowChip`/`WindowGroupChip` chrome dedup** — extracted shared `ChipChrome` view (output-identical; the four duplicated helpers removed from both structs). NOT changed: the `NotificationBadge` offset difference (`x:4` vs `x:6`) — visible behavior change, leave until intent is confirmed.
- [ ] **`BarController` animate mirror duplication.** `animateCollapse`/`animateExpand` are mirror images each recomputing `visibleFrame`/`hiddenFrame` 4×; consolidate to one `animate(toCollapsed:)` + a geometry struct. Deferred: touches the collapse/expand animation path — verify motion visually.

#### Remaining — concurrency (moderate)
- [ ] **`PinnedAppsStore.load()` blocks main at launch.** Init runs on the main thread at launch → `load()` → `resolvedPinnedApp` calls synchronous `NSWorkspace.urlForApplication(withBundleIdentifier:)` (LaunchServices) + `fileExists` per pin. Fix: render from persisted paths immediately, resolve/validate async, publish corrections on main. Deferred: needs care around first-paint ordering.

#### Remaining — low-value / optional (documented; act only with a real driver)
- [ ] **`SwitcherTile` resolves app icon per render** (`SwitcherView.swift`). Low: the codebase already documents the `NSRunningApplication` PID lookup as constant-time (`BarSupport.swift:22`).
- [ ] **Redundant Spaces SPI on the 1s poll** (`WindowEnumerator.currentFullscreenSpaceIDs`). Redundancy nit, not an expensive path — the heavy per-space loop is already guarded and `SpacesStore`'s cache excludes fullscreen so it can't be reused as-is. Act only if it profiles hot.
- [ ] **`runningApplications` dict rebuilt every 1s** (`WindowEnumerator.swift:27-32`). Optional: reuse a `RunningAppsStore` pid→app map — caveat: an event-driven map can briefly miss a just-launched app's bundleID.
- [ ] **Launcher scoring re-lowercases per keystroke** (`AppSearchScorer`). Imperceptible at ~hundreds of short names. Optional: precompute lowercased name+words on `AppEntry` at scan time. Do NOT add `.debounce` — it only adds latency to an instant local search.
- [ ] **Badge reader micro-opt** (`BadgeStore.read()`): linear-scan + `Bundle(url:)` per 2.5s poll; `Bundle` is internally cached and the AX IPC to the Dock dominates, so gains are marginal.
- [x] **`BehaviorTab` DI** — now receives `settings` via init like the other tabs (was defaulting to `.shared` inline).
- [ ] **Minor consistency (remaining).** `MenuBarController` sets menu title/image in both Combine sinks and `menuNeedsUpdate` — NOT changed: the sinks keep item titles live while the menu is open during a hotkey-driven state change, so removing them is a behavior change, not a mechanical dedup. `CollapsedTabPosition`/`CollapsedTabPlacement` duplicate only the two-case list (mapping is already single-source in Core). `collapsedTabWidth = 56` duplicated between `BarController.swift:17` and `CollapsedTabMetrics.clusterWidth`. `LauncherController.resignObserver` never removed (singleton-safe).
