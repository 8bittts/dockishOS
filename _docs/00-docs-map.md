# dockishOS Documentation Map

Quick index of documentation surfaces. Product: macOS menu-bar app launcher + window switcher. Agent routing: `AGENTS.md`.

This repo uses `docs/` for the public landing mirror and root markdown for engineering — there is no numbered `_docs/` series.

---

## Documentation surfaces

| Doc | Audience | Owns |
|-----|----------|------|
| `README.md` | Users + developers | Features, Homebrew, permissions, smoke overview |
| `BUILD.md` | **Developers (canonical release path)** | Sign, notarize, Sparkle, release scripts |
| `CHANGELOG.md` | Users | Version history |
| `docs/index.md` | Web/download landing | Short product mirror of README |
| `todos.md` | Operator | Backlog (currently empty — stable utility) |
| `AGENTS.md` | Agents | Sparkle vendoring, release caveats → points to `BUILD.md` |

## Release engineering

Authoritative path: **`BUILD.md`**, not `docs/index.md`.
