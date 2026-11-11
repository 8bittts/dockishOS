# DockishOS Documentation Map

macOS menu-bar utility that shows a floating, per-display app bar for the current Space, with a window switcher.
Agent routing lives in `AGENTS.md`; this index follows the fleet documentation standard that `/docs` audits against.

## Owner docs

| Doc                    | Owns                                                                                                          |
| ---------------------- | ------------------------------------------------------------------------------------------------------------- |
| `00-foundation.md`     | History and the decision record                                                                               |
| `01-architecture.md`   | Stack, the core and app targets, modules, bundle metadata, build pipeline                                     |
| `02-design-system.md`  | Marks, materials and color, motion, accessibility contracts                                                   |
| `04-security.md`       | Permissions, private APIs, signing and notarization, update-feed trust, local data                            |
| `05-infrastructure.md` | Build modes, release flow, notarization and Sparkle key setup, Sparkle vendoring, distribution, appcast rules |
| `09-quality.md`        | Gates, test strategy, traps, manual verification                                                              |
| `todos.md`             | The only backlog; active work only                                                                            |

## Not applicable

- `03-data.md`: the only persisted data is pinned apps and preferences, owned by `01-architecture.md`.
- `06-payments.md`, `07-email.md`, `08-growth.md`, `10-gtm.md`: the app is free, sends nothing, and has no analytics or marketing surface.

## Other surfaces

| Path                       | Notes                                                                                                                                                   |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`                | Orientation, Sparkle vendoring and release caveats that bind every change                                                                               |
| `README.md`                | User-facing features, download, Homebrew, permissions, quick build; points here                                                                         |
| `CHANGELOG.md`             | User-facing version history; release tooling reads its `Unreleased` section                                                                             |
| `docs/index.md`            | GitHub Pages landing; a short product mirror of the README                                                                                              |
| `appcast.xml`              | Generated, EdDSA-signed Sparkle feed; never hand-edited                                                                                                 |
| `Casks/dockishos.rb`       | Homebrew Cask; the release script pins it to each release's version and checksum                                                                        |
| `tools/sparkle/VERSION`    | Sparkle vendoring pin read by the build preflight                                                                                                       |
| `.periphery.yml`           | Periphery configuration for the unused-code scan                                                                                                        |
| `.githooks/commit-msg`     | Tracked commit hook that refuses AI attribution; `scripts/setup-hooks.sh` wires it                                                                      |
| `../../movingpaper/_docs/` | Sibling macOS app; it shares the Sparkle pipeline and cites this repository's re-vendor procedure ([its index](../../movingpaper/_docs/00-docs-map.md)) |

## Authority order

Code, scripts and tests, then the owner doc, then `AGENTS.md`, then `README.md`.

## Known doc drift

- A past `CHANGELOG.md` entry cites `BUILD.md`, the former name of `05-infrastructure.md`; released changelog entries are not edited.
