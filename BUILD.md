# Building DockishOS

Build, sign, and (optionally) notarize a DockishOS `.dmg` for distribution.

All commands below are wrappers around scripts in [`scripts/`](scripts/). Run them from the repo root.

---

## Modes

| Command | Behavior |
|---|---|
| `./scripts/build_and_run.sh` | Build a real local `.app` bundle at `build/DockishOS.app` and launch it |
| `./scripts/build_and_run.sh --verify` | Build, launch, and confirm the app process is alive |
| `./scripts/build_and_run.sh --logs` | Build, launch, and stream DockishOS unified logs |
| `./scripts/build_and_run.sh --debug` | Build the bundle, then launch the binary under `lldb` |
| `./scripts/build-dmg.sh` | Default: signed + notarized release DMG (requires Developer ID + notary keychain profile) |
| `./scripts/build-dmg.sh --local` | Signed DMG, **skip** notarization (fastest path that still produces a draggable DMG) |
| `./scripts/build-dmg.sh --unsigned` | Ad-hoc sign only — no Developer ID required (good for first-time bootstrapping) |
| `./scripts/build-dmg.sh --build-only` | Assemble `DockishOS.app` only, no DMG |
| `./scripts/release-dockishOS.sh` | End-to-end release: bump version, build, tag, push, draft GitHub release |

---

## Process

### 1. Pre-flight

Surface any compile errors before kicking off the longer pipeline:

```bash
swift build 2>&1 | tail -10
```

If the build fails, stop here — the DMG pipeline will fail at the same step but slower.

### 2. Run the requested build

```bash
# Local development bundle:
./scripts/build_and_run.sh

# Local development bundle + process check:
./scripts/build_and_run.sh --verify

# Local development bundle + unified logs:
./scripts/build_and_run.sh --logs

# Local development bundle under lldb:
./scripts/build_and_run.sh --debug

# Default — signed + notarized release DMG:
./scripts/build-dmg.sh

# --local: signed but not notarized (faster):
./scripts/build-dmg.sh --local

# --unsigned: ad-hoc only (no Developer ID required):
./scripts/build-dmg.sh --unsigned

# --build-only: just the .app, no DMG:
./scripts/build-dmg.sh --build-only

# release: full version bump + GitHub release flow:
./scripts/release-dockishOS.sh
```

### 3. Artifacts

After a successful run, look in `build/`:

- Always: `build/DockishOS.app`
- DMG-producing modes: `build/DockishOS-<version>.dmg`
- DMG-producing modes: SHA-256 at `build/DockishOS-<version>.sha256`
- Notarized mode: submission JSON at `build/DockishOS-<version>.notary-submission.json`
- Notarized mode: look for `Notarization ticket stapled` in the build output
- DMG-producing modes: the release script prints the GitHub download URL

### 4. Sanity checks

```bash
# Confirm the .app launches:
open -n build/DockishOS.app
sleep 2
pgrep -x DockishOS >/dev/null && echo "OK app launched" && pkill -x DockishOS

# Confirm the DMG is readable:
hdiutil verify build/DockishOS-*.dmg | tail -3
```

---

## Notarization setup (one-time)

The default mode requires a keychain profile named `YEN-Notarization`. If notarization is being skipped because the profile doesn't exist:

```bash
xcrun notarytool store-credentials YEN-Notarization \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password YOUR_APP_SPECIFIC_PASSWORD
```

Override the profile name per-build with `DOCKISHOS_NOTARY_PROFILE=…` in the environment.

---

## Sparkle EdDSA key (one-time)

```bash
./tools/sparkle/bin/generate_keys
```

Writes a private key to the login keychain and prints the public key. Copy the public key into `Resources/Info.plist` under `SUPublicEDKey`. The same key signs every Sparkle-enabled app — only one developer key is needed.

---

## Upgrading the Sparkle framework

The vendored Sparkle framework lives at `tools/sparkle/Sparkle.framework`. It is pinned to a specific upstream release in `tools/sparkle/VERSION`, and `scripts/build-dmg.sh` refuses to proceed if any required helper is missing or the framework binary's SHA-256 doesn't match the pin.

This guards against the 0.014/0.015 regression where `Updater.app` silently disappeared from the framework and shipped a broken in-app updater. Follow this exact procedure when bumping Sparkle:

1. Pick the target release from <https://github.com/sparkle-project/Sparkle/releases> and download the `Sparkle-<version>.tar.xz` archive. Don't use Swift Package Manager artifacts — they're missing the helper apps.
2. Extract the archive to a scratch directory and replace `tools/sparkle/Sparkle.framework` and `tools/sparkle/bin/` with the new versions. Copy the **entire** `Sparkle.framework/Versions/B/` tree, including `Updater.app`, `Autoupdate`, and both `XPCServices/*.xpc` bundles.
3. Refresh `tools/sparkle/VERSION`:

   ```bash
   shasum -a 256 tools/sparkle/Sparkle.framework/Versions/B/Sparkle
   ```

   Paste the hash into `sparkle_binary_sha256` and update `sparkle_version`, `sparkle_build`, and `sparkle_source`. Leave `required_paths` alone unless Sparkle changed its on-disk layout.
4. Run `./scripts/build-dmg.sh --build-only` and confirm the preflight prints `Verified vendored Sparkle <version> (binary SHA-256 matches pin)`. If it fails, you missed a file in step 2 or the pin is wrong.
5. Sanity-check the auto-update path end-to-end on a non-production machine before tagging a release.

---

## Release notes

Keep user-facing changes under `CHANGELOG.md` → `## [Unreleased]`. The release flow uses that section for Sparkle release notes and GitHub release notes. For one-off appcast generation, override with `SPARKLE_NOTES` when needed.

---

## Common failure modes

| Symptom | Likely cause |
|---|---|
| `Source Info.plist not found` | Running from a directory other than the repo root. The script `cd`s into the repo's own path — re-check. |
| `No Developer ID found — falling back to ad-hoc signing` | No Developer ID Application certificate in the login keychain. Add one or use `--unsigned`. |
| `Notarization skipped — no keychain profile` | Run the `notarytool store-credentials` snippet above. |
| `Notarization rejected` | Inspect `build/DockishOS-<version>.notary-submission.json`; the script also fetches the notary log when a submission ID is available. |
| Signing retry loops | Apple's timestamp server is slow. The script auto-retries 5×. |
| `xcrun stapler staple` fails | Notarization succeeded but propagation is slow. The script auto-retries 10×. |

---

## Safety

- **Never commit the contents of `build/`** — it's gitignored. Artifacts ship to GitHub Releases via `release-dockishOS.sh`, not into the git tree.
- **Don't override `DOCKISHOS_VERSION` casually** — the version in `Resources/Info.plist` is the source of truth and `release-dockishOS.sh` bumps it for you.
- The release script updates the README's `<!-- version-badge -->` and `<!-- download-link -->` markers — never hand-edit those.
