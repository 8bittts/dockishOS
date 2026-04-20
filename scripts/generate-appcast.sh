#!/usr/bin/env bash
#
# generate-appcast.sh — Generate a signed Sparkle appcast.xml for DockishOS.
#
# Reads version from build/DockishOS.app/Contents/Info.plist, drafts release
# notes from git history (or accepts overrides via env), and runs Sparkle's
# generate_appcast against the latest DMG.
#
# Run after build-dmg.sh has produced the signed DMG.
#
# Environment variables (all optional):
#   SPARKLE_NOTES                  Inline release notes (one bullet per line)
#   SPARKLE_NOTES_SINCE            Git tag to diff against for auto notes
#   SPARKLE_ED_KEYCHAIN_ACCOUNT    Keychain account for the EdDSA private key
#                                  (default: ed25519 — the Sparkle convention)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="DockishOS"
GITHUB_REPO="8bittts/dockishOS"
APPCAST_TOOL="tools/sparkle/bin/generate_appcast"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

APP_BUNDLE="build/${APP_NAME}.app"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
OUTPUT="build/appcast.xml"
CHANGELOG_FILE="CHANGELOG.md"

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
step()  { printf "\033[1;36m  ->\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31mERROR:\033[0m %s\n" "$1" >&2; exit 1; }

[ -d "$APP_BUNDLE" ]   || fail "App bundle not found at ${APP_BUNDLE} — run build-dmg.sh first"
[ -x "$APPCAST_TOOL" ] || fail "Sparkle generate_appcast not found at ${APPCAST_TOOL}"

VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$INFO_PLIST")"

DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="build/${DMG_FILENAME}"
[ -f "$DMG_PATH" ] || fail "DMG not found at ${DMG_PATH}"

info "Generating signed appcast for ${APP_NAME} v${VERSION} (build ${BUILD_NUMBER})"

DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/"

release_notes_html() {
    local ver="$1"
    local items="$2"
    cat <<HTML
<style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 16px 20px; line-height: 1.6; color: #1d1d1f; }
    h2 { font-size: 17px; font-weight: 600; margin: 0 0 14px 0; }
    ul { padding-left: 20px; margin: 0; }
    li { margin-bottom: 6px; font-size: 13px; }
    .footer { margin-top: 16px; font-size: 11px; color: #86868b; }
    @media (prefers-color-scheme: dark) {
        body { color: #f5f5f7; }
        .footer { color: #a1a1a6; }
    }
</style>
<h2>What's New</h2>
<ul>
$(printf '%b' "$items")</ul>
<p class="footer">${APP_NAME} ${ver}</p>
HTML
}

changelog_unreleased_items() {
    [ -f "$CHANGELOG_FILE" ] || return 0
    awk '
        /^## \[Unreleased\]/ { capture = 1; next }
        capture && /^## / { exit }
        capture { print }
    ' "$CHANGELOG_FILE" \
        | sed -e '/^[[:space:]]*$/d' -e '/^### /d' -e 's/^- //'
}

generate_release_notes() {
    local ver="$1"

    if [ -n "${SPARKLE_NOTES:-}" ]; then
        local items=""
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local cap
            cap=$(echo "$line" | awk '{$1=toupper(substr($1,1,1)) substr($1,2)} 1')
            items="${items}    <li>${cap}</li>\n"
        done <<< "$(printf '%b' "$SPARKLE_NOTES")"
        release_notes_html "$ver" "$items"
        return
    fi

    local changelog_items
    changelog_items="$(changelog_unreleased_items)"
    if [ -n "$changelog_items" ]; then
        local items=""
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            items="${items}    <li>${line}</li>\n"
        done <<< "$changelog_items"
        release_notes_html "$ver" "$items"
        return
    fi

    local prev_tag
    if [ -n "${SPARKLE_NOTES_SINCE:-}" ]; then
        prev_tag="$SPARKLE_NOTES_SINCE"
    else
        prev_tag=$(git tag --sort=-v:refname | grep '^v' | grep -vx "v${ver}" | head -1)
    fi

    local commits=""
    if [ -n "$prev_tag" ]; then
        commits=$(git log "${prev_tag}..HEAD" --pretty=format:"%s" --no-merges 2>/dev/null \
            | grep -v "^release:" \
            | grep -vi "appcast" \
            | grep -vi "sparkle" \
            | grep -vi "build script" \
            | grep -vi "build-dmg" \
            | head -8 || true)
    fi
    [ -z "$commits" ] && commits="Bug fixes and performance improvements"

    local items=""
    while IFS= read -r msg; do
        [ -z "$msg" ] && continue
        local clean
        clean=$(echo "$msg" | sed 's/^[a-z]*: *//')
        clean=$(echo "$clean" | awk '{$1=toupper(substr($1,1,1)) substr($1,2)} 1')
        items="${items}    <li>${clean}</li>\n"
    done <<< "$commits"
    release_notes_html "$ver" "$items"
}

ARCHIVES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dockishOS-appcast.XXXXXX")"
trap 'rm -rf "$ARCHIVES_DIR"' EXIT

cp "$DMG_PATH" "${ARCHIVES_DIR}/${DMG_FILENAME}"
NOTES_FILE="${ARCHIVES_DIR}/${APP_NAME}-${VERSION}.html"
generate_release_notes "$VERSION" > "$NOTES_FILE"
step "Prepared release notes: ${NOTES_FILE}"

GENERATE_CMD=(
    "$APPCAST_TOOL"
    --account "${SPARKLE_ED_KEYCHAIN_ACCOUNT:-ed25519}"
    --download-url-prefix "$DOWNLOAD_PREFIX"
    --embed-release-notes
    -o "$OUTPUT"
    "$ARCHIVES_DIR"
)

info "Generating signed appcast"
"${GENERATE_CMD[@]}"

[ -f "$OUTPUT" ] || fail "Appcast generation failed — missing ${OUTPUT}"

if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$OUTPUT" 2>&1 && step "XML validated"
fi

REQUIRE_SIGNED_FEED="$("$PLIST_BUDDY" -c 'Print :SURequireSignedFeed' "$INFO_PLIST" 2>/dev/null || echo false)"
if [ "$REQUIRE_SIGNED_FEED" = "true" ]; then
    if grep -q "sparkle-signatures:" "$OUTPUT"; then
        step "Verified embedded Sparkle feed signature"
    else
        fail "Signed feed required but ${OUTPUT} is missing the embedded sparkle-signatures block"
    fi
fi

step "Appcast written to ${OUTPUT}"
