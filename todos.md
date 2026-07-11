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

(No active phase.)

### Follow-On Candidates
Not active work. Promote only one item at a time into `#### Phase N` in `### Work TODOs` when implementation starts.

The full-codebase audit is implemented — see git history. Only items needing a real product/design decision remain; the net-neutral/net-negative micro-opts were considered and dropped (they'd trade correctness or add state for no measurable gain).

- [ ] **`NotificationBadge` offset `x:4` vs `x:6`** between `WindowChip` and `WindowGroupChip` — pick the intended value and align both (needs a design call).
- [ ] **`MenuBarController` menu-state: keep the live-while-open Combine sinks or not?** They update menu-item titles live if collapse is toggled via hotkey while the menu is open; `menuNeedsUpdate` alone would only refresh on open. Decide whether live-while-open matters before touching it.
