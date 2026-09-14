# DockishOS TODOs

---
## MUST FOLLOW RULES and PROTOCOLS:
1. Never remove, delete, or modify this list unless directed to do so.
2. Active work only. Completed work lives in git history.
3. This is the ONLY TODO/backlog file.
4. Keep clear separation of concerns with phase-based checklists and zero task duplication.
5. Validate, review, and test each phase before moving to the next phase.
6. Stage and commit only files touched for the active phase. Ignore unrelated edits from other agents.
7. Review and update `CLAUDE.md` / `AGENTS.md` when a finding will materially help future agents; both are tracked (`CLAUDE.md` symlinks to `AGENTS.md`).
8. Update `README.md` / `BUILD.md` when user-facing behavior or developer workflow changes. Re-run signing/notarization only for release, packaging, entitlement, or distribution changes.

---
## BACKLOG

### Work TODOs

Promote exactly one Phase into active work at a time. Phase ordering is intentional.

#### Phase 2 — Native chrome
Source: Apple HIG menu-bar extras, app icons, color, settings, search fields.

- [ ] Template menu-bar extra from the branded mark (`isTemplate = true`); keep the color icon for About/Finder.
- [ ] Stop baking a squircle into `scripts/generate-app-icon.swift`; ship a square 1024 asset and let the system mask it.
- [ ] Use `systemRed` for notification badges; drop hardcoded black fills on the collapsed tab.
- [ ] Dim or remove Settings miniaturize and zoom.
- [ ] Add a Clear button to the launcher search field.

### Follow-On Candidates
Not active work. Promote only one item at a time into `#### Phase N` in `### Work TODOs` when implementation starts.

#### Phase 3 — Writing and menus
- One Pin to Bar / Unpin from Bar pair; do not mark Unpin destructive.
- Use a real ellipsis and Untitled; show copyright on the About tab.
- Hide Move Left / Move Right at the ends of the pinned context menu.
- Stop showing raw `OSStatus` in hotkey-conflict menu copy.
- Keep a non-color window-count cue when the notification badge wins.
