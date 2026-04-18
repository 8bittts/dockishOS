#!/usr/bin/env bash
#
# release-dockishOS.sh — End-to-end release: bump version, build signed +
# notarized DMG, tag, push, draft GitHub release with checksum.
#
# Usage:
#   ./scripts/release-dockishOS.sh
#
# Requires:
#   - Clean git state on Resources/Info.plist and README.md
#   - `gh` CLI authenticated for the dockishOS repo
#   - A configured notary keychain profile (see build-dmg.sh)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="DockishOS"
GITHUB_REPO="8bittts/dockishOS"
PLIST_FILE="Resources/Info.plist"
README_FILE="README.md"
ROOT_APPCAST_FILE="appcast.xml"

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33mWARN:\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31mERROR:\033[0m %s\n" "$1" >&2; exit 1; }
step()  { printf "\033[1;36m  ->\033[0m %s\n" "$1"; }

plist_set() {
    local plist="$1" key="$2" type="$3" value="$4"
    if /usr/libexec/PlistBuddy -c "Print :${key}" "$plist" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$plist"
    else
        /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "$plist"
    fi
}

bump_version() {
    local current="$1"
    local major="${current%%.*}"
    local minor="${current#*.}"
    local minor_num=$((10#$minor))
    minor_num=$((minor_num + 1))
    if [ "$minor_num" -ge 1000 ]; then
        major=$((major + 1))
        minor_num=1
    fi
    printf "%d.%03d" "$major" "$minor_num"
}

update_readme() {
    local version="$1"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/${APP_NAME}-${version}.dmg"
    perl -0pi -e "s|<!-- download-link -->.*?<!-- /download-link -->|<!-- download-link -->\n[**Download ${APP_NAME} v${version}**](${download_url})\n<!-- /download-link -->|s" "$README_FILE"
    perl -0pi -e "s|<!-- version-badge -->.*?<!-- /version-badge -->|<!-- version-badge -->v${version}<!-- /version-badge -->|s" "$README_FILE"
}

[ -f "$PLIST_FILE" ] || fail "Missing ${PLIST_FILE}"
[ -f "$README_FILE" ] || fail "Missing ${README_FILE}"
command -v gh >/dev/null 2>&1 || fail "gh CLI is required"

if ! git diff --quiet -- "$PLIST_FILE" "$README_FILE"; then
    fail "Unstaged changes in ${PLIST_FILE} or ${README_FILE}. Commit or stash first."
fi
if [ -f "$ROOT_APPCAST_FILE" ] && ! git diff --quiet -- "$ROOT_APPCAST_FILE"; then
    fail "Unstaged changes in ${ROOT_APPCAST_FILE}. Commit or stash first."
fi
if ! git diff --cached --quiet -- "$PLIST_FILE" "$README_FILE"; then
    fail "Staged changes in ${PLIST_FILE} or ${README_FILE}. Release from a clean metadata state."
fi
if [ -f "$ROOT_APPCAST_FILE" ] && ! git diff --cached --quiet -- "$ROOT_APPCAST_FILE"; then
    fail "Staged changes in ${ROOT_APPCAST_FILE}. Release from a clean metadata state."
fi

CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_FILE")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_FILE")"
NEXT_VERSION="$(bump_version "$CURRENT_VERSION")"
NEXT_BUILD="$((CURRENT_BUILD + 1))"

info "Releasing ${APP_NAME} v${NEXT_VERSION} (build ${NEXT_BUILD})"

DOCKISHOS_VERSION="$NEXT_VERSION" \
DOCKISHOS_BUILD="$NEXT_BUILD" \
"${REPO_ROOT}/scripts/build-dmg.sh"

APPCAST_FILE="build/appcast.xml"
[ -f "$APPCAST_FILE" ] || fail "Missing appcast at ${APPCAST_FILE} — Sparkle pipeline broken"
cp "$APPCAST_FILE" "$ROOT_APPCAST_FILE"
step "Updated ${ROOT_APPCAST_FILE} from generated appcast"

plist_set "$PLIST_FILE" "CFBundleShortVersionString" string "$NEXT_VERSION"
plist_set "$PLIST_FILE" "CFBundleVersion" string "$NEXT_BUILD"
update_readme "$NEXT_VERSION"
step "Updated release metadata"

git add "$PLIST_FILE" "$README_FILE" "$ROOT_APPCAST_FILE"
git commit -m "release: ${APP_NAME} v${NEXT_VERSION}"
step "Committed release metadata"

git tag -a "v${NEXT_VERSION}" -m "${APP_NAME} v${NEXT_VERSION}"
step "Tagged v${NEXT_VERSION}"

git push origin HEAD
git push origin "v${NEXT_VERSION}"
step "Pushed commit and tag"

DMG_FILE="build/${APP_NAME}-${NEXT_VERSION}.dmg"
SHA_FILE="build/${APP_NAME}-${NEXT_VERSION}.sha256"

[ -f "$DMG_FILE" ]     || fail "Missing release DMG at ${DMG_FILE}"
[ -f "$SHA_FILE" ]     || fail "Missing checksum at ${SHA_FILE}"
[ -f "$APPCAST_FILE" ] || fail "Missing appcast at ${APPCAST_FILE} — Sparkle pipeline broken"

RELEASE_NOTES="$(mktemp)"
trap 'rm -f "$RELEASE_NOTES"' EXIT

cat > "$RELEASE_NOTES" <<EOF
${APP_NAME} v${NEXT_VERSION}

Download the DMG, open it, and drag ${APP_NAME}.app to /Applications.
Launch it from Applications. The app lives as a menu-bar accessory — look for
the floating bar at the bottom of every display.

**SHA-256:** $(cat "$SHA_FILE")
EOF

gh release create "v${NEXT_VERSION}" \
    --repo "$GITHUB_REPO" \
    --verify-tag \
    --title "${APP_NAME} v${NEXT_VERSION}" \
    --notes-file "$RELEASE_NOTES" \
    "$DMG_FILE" \
    "$SHA_FILE" \
    "$APPCAST_FILE"
step "Created GitHub release"

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${NEXT_VERSION}/${APP_NAME}-${NEXT_VERSION}.dmg"
HTTP_CODE=""
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    HTTP_CODE="$(curl -sI -o /dev/null -w "%{http_code}" -L \
        -H "Cache-Control: no-cache" \
        "${DOWNLOAD_URL}?t=$(date +%s)")"
    [ "$HTTP_CODE" = "200" ] && break
    step "Download URL not ready (HTTP ${HTTP_CODE}) — retry ${attempt}/10 in 3s"
    sleep 3
done
[ "$HTTP_CODE" = "200" ] || fail "Download URL returned HTTP ${HTTP_CODE} after 10 attempts"
step "Verified release download URL"

# Wait for the repo-hosted appcast.xml that Sparkle reads.
APPCAST_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/appcast.xml"
APPCAST_TMP="$(mktemp "${TMPDIR:-/tmp}/dockishOS-live-appcast.XXXXXX.xml")"
APPCAST_OK=false
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsSL -H "Cache-Control: no-cache" "${APPCAST_URL}?t=$(date +%s)" -o "$APPCAST_TMP" \
        && grep -q "<sparkle:shortVersionString>${NEXT_VERSION}</sparkle:shortVersionString>" "$APPCAST_TMP" \
        && grep -q "sparkle-signatures:" "$APPCAST_TMP"; then
        APPCAST_OK=true
        break
    fi
    step "Live appcast not ready — retry ${attempt}/10 in 3s"
    sleep 3
done
rm -f "$APPCAST_TMP"
[ "$APPCAST_OK" = true ] || fail "Live appcast.xml at ${APPCAST_URL} did not propagate after 10 attempts"
step "Verified live signed appcast"

echo ""
info "Release complete"
echo "  Version:  v${NEXT_VERSION} (build ${NEXT_BUILD})"
echo "  App:      build/${APP_NAME}.app"
echo "  DMG:      ${DMG_FILE}"
echo "  Checksum: ${SHA_FILE}"
echo "  Release:  https://github.com/${GITHUB_REPO}/releases/tag/v${NEXT_VERSION}"
echo "  Download: ${DOWNLOAD_URL}"
echo ""
