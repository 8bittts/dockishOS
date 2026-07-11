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

Nearly the whole audit is now implemented (commits through `7d82c29`). Four more items landed via isolated-worktree agents and were merged: `BarController` animate consolidation (`a41eb1f`), `PinnedAppsStore.load()` off-main resolution (`4a91f28`), fullscreen-space-ID short-TTL cache (`41e59e5`), and launcher-scoring precompute (`7d82c29`). The `ChipChrome` extraction and `BehaviorTab` DI also shipped (`156fb93`).

#### Remaining — needs product judgment or the running app (not mechanical)
- [ ] **`NotificationBadge` offset `x:4` vs `x:6`** between `WindowChip` and `WindowGroupChip`. A visible position change — pick the intended value and align both.
- [ ] **`MenuBarController` double menu-state set.** The Combine sinks keep menu-item titles live *while the menu is open* during a hotkey-driven state change; `menuNeedsUpdate` only fires on open. Removing the sinks is a real behavior change, not a dedup — decide whether live-while-open updates matter.
- [ ] **Manual verify (needs GUI):** grouped-by-app chip cycles through all of an app's windows (validates the shipped `activateNext` fix).

#### Remaining — genuinely optional / net-neutral (documented; act only with a real driver)
- [ ] **`SwitcherTile` icon per render** — codebase documents the `NSRunningApplication` PID lookup as constant-time (`BarSupport.swift:22`); caching adds state for no measurable win.
- [ ] **`runningApplications` dict rebuilt every 1s** (`WindowEnumerator.swift:27-32`). Not taken: an event-driven `RunningAppsStore` map can briefly miss a just-launched app's bundleID — correctness caveat outweighs the tiny allocation saving.
- [ ] **Badge reader micro-opt** (`BadgeStore.read()`): `Bundle` is internally cached and the AX IPC to the Dock dominates — marginal.
- [ ] **Constant/enum consistency.** `collapsedTabWidth = 56` (`BarController.swift:17`) vs `CollapsedTabMetrics.clusterWidth` — not merged, to avoid falsely coupling two independently-defined constants. `CollapsedTabPosition`/`CollapsedTabPlacement` duplicate only the two-case list (persist/migration mapping is already single-source in Core, touches persisted values). `LauncherController.resignObserver` never removed (singleton-safe).
