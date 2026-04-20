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
CHANGELOG_FILE="CHANGELOG.md"
RELEASE_NOTES=""
APPCAST_TMP=""

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33mWARN:\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31mERROR:\033[0m %s\n" "$1" >&2; exit 1; }
step()  { printf "\033[1;36m  ->\033[0m %s\n" "$1"; }

cleanup_on_exit() {
    [ -z "$RELEASE_NOTES" ] || rm -f "$RELEASE_NOTES"
    [ -z "$APPCAST_TMP" ] || rm -f "$APPCAST_TMP"
}
trap cleanup_on_exit EXIT

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

changelog_unreleased_markdown() {
    [ -f "$CHANGELOG_FILE" ] || return 0
    awk '
        /^## \[Unreleased\]/ { capture = 1; next }
        capture && /^## / { exit }
        capture { print }
    ' "$CHANGELOG_FILE" | sed '/^[[:space:]]*$/d'
}

changelog_unreleased_items() {
    changelog_unreleased_markdown \
        | sed -e '/^### /d' -e 's/^- //' \
        | sed '/^[[:space:]]*$/d'
}

tag_exists() {
    git rev-parse -q --verify "refs/tags/$1" >/dev/null
}

tag_points_at_head() {
    local tag="$1"
    [ "$(git rev-list -n 1 "$tag" 2>/dev/null || true)" = "$(git rev-parse HEAD)" ]
}

release_exists() {
    gh release view "$1" --repo "$GITHUB_REPO" >/dev/null 2>&1
}

run_build() {
    local version="$1" build="$2" notes="$3"
    if [ -n "$notes" ]; then
        SPARKLE_NOTES="$notes" \
        DOCKISHOS_VERSION="$version" \
        DOCKISHOS_BUILD="$build" \
        "${REPO_ROOT}/scripts/build-dmg.sh"
    else
        DOCKISHOS_VERSION="$version" \
        DOCKISHOS_BUILD="$build" \
        "${REPO_ROOT}/scripts/build-dmg.sh"
    fi
}

write_release_notes() {
    local version="$1" sha_file="$2" markdown="$3"
    RELEASE_NOTES="$(mktemp -t dockishOS-release-notes)"
    {
        printf "%s v%s\n\n" "$APP_NAME" "$version"
        if [ -n "$markdown" ]; then
            printf "%s\n\n" "$markdown"
        else
            printf "Bug fixes and performance improvements.\n\n"
        fi
        printf "Download the DMG, open it, and drag %s.app to /Applications.\n" "$APP_NAME"
        printf "Launch it from Applications. The app lives as a menu-bar accessory.\n\n"
        printf "**SHA-256:** %s\n" "$(cat "$sha_file")"
    } > "$RELEASE_NOTES"
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
if [ -f "$CHANGELOG_FILE" ] && ! git diff --quiet -- "$CHANGELOG_FILE"; then
    fail "Unstaged changes in ${CHANGELOG_FILE}. Commit or stash first."
fi
if ! git diff --cached --quiet -- "$PLIST_FILE" "$README_FILE"; then
    fail "Staged changes in ${PLIST_FILE} or ${README_FILE}. Release from a clean metadata state."
fi
if [ -f "$ROOT_APPCAST_FILE" ] && ! git diff --cached --quiet -- "$ROOT_APPCAST_FILE"; then
    fail "Staged changes in ${ROOT_APPCAST_FILE}. Release from a clean metadata state."
fi
if [ -f "$CHANGELOG_FILE" ] && ! git diff --cached --quiet -- "$CHANGELOG_FILE"; then
    fail "Staged changes in ${CHANGELOG_FILE}. Release from a clean metadata state."
fi

CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_FILE")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_FILE")"
NEXT_VERSION="$(bump_version "$CURRENT_VERSION")"
NEXT_BUILD="$((CURRENT_BUILD + 1))"
CURRENT_TAG="v${CURRENT_VERSION}"
RESUME_RELEASE=false
if tag_exists "$CURRENT_TAG" && tag_points_at_head "$CURRENT_TAG"; then
    RESUME_RELEASE=true
    RELEASE_VERSION="$CURRENT_VERSION"
    RELEASE_BUILD="$CURRENT_BUILD"
else
    RELEASE_VERSION="$NEXT_VERSION"
    RELEASE_BUILD="$NEXT_BUILD"
fi
RELEASE_TAG="v${RELEASE_VERSION}"
CHANGELOG_MARKDOWN="$(changelog_unreleased_markdown)"
CHANGELOG_ITEMS="$(changelog_unreleased_items)"

if [ "$RESUME_RELEASE" = true ]; then
    info "Resuming ${APP_NAME} ${RELEASE_TAG} at current HEAD"
else
    info "Releasing ${APP_NAME} v${RELEASE_VERSION} (build ${RELEASE_BUILD})"
fi

APPCAST_FILE="build/appcast.xml"
DMG_FILE="build/${APP_NAME}-${RELEASE_VERSION}.dmg"
SHA_FILE="build/${APP_NAME}-${RELEASE_VERSION}.sha256"

if [ "$RESUME_RELEASE" = true ] && [ -f "$DMG_FILE" ] && [ -f "$SHA_FILE" ] && [ -f "$APPCAST_FILE" ]; then
    step "Using existing release artifacts"
else
    run_build "$RELEASE_VERSION" "$RELEASE_BUILD" "$CHANGELOG_ITEMS"
fi

[ -f "$DMG_FILE" ]     || fail "Missing release DMG at ${DMG_FILE}"
[ -f "$SHA_FILE" ]     || fail "Missing checksum at ${SHA_FILE}"
[ -f "$APPCAST_FILE" ] || fail "Missing appcast at ${APPCAST_FILE} — Sparkle pipeline broken"

if [ "$RESUME_RELEASE" != true ]; then
    cp "$APPCAST_FILE" "$ROOT_APPCAST_FILE"
    step "Updated ${ROOT_APPCAST_FILE} from generated appcast"

    plist_set "$PLIST_FILE" "CFBundleShortVersionString" string "$RELEASE_VERSION"
    plist_set "$PLIST_FILE" "CFBundleVersion" string "$RELEASE_BUILD"
    update_readme "$RELEASE_VERSION"
    step "Updated release metadata"

    git add "$PLIST_FILE" "$README_FILE" "$ROOT_APPCAST_FILE"
    git commit -m "release: ${APP_NAME} v${RELEASE_VERSION}"
    step "Committed release metadata"

    git tag -a "$RELEASE_TAG" -m "${APP_NAME} v${RELEASE_VERSION}"
    step "Tagged ${RELEASE_TAG}"

    git push origin HEAD
    git push origin "$RELEASE_TAG"
    step "Pushed commit and tag"
else
    git push origin HEAD
    git push origin "$RELEASE_TAG"
    step "Verified pushed commit and tag"
fi

write_release_notes "$RELEASE_VERSION" "$SHA_FILE" "$CHANGELOG_MARKDOWN"

if release_exists "$RELEASE_TAG"; then
    gh release upload "$RELEASE_TAG" \
        --repo "$GITHUB_REPO" \
        --clobber \
        "$DMG_FILE" \
        "$SHA_FILE" \
        "$APPCAST_FILE"
    step "Uploaded release assets to ${RELEASE_TAG}"
else
    gh release create "$RELEASE_TAG" \
        --repo "$GITHUB_REPO" \
        --verify-tag \
        --title "${APP_NAME} v${RELEASE_VERSION}" \
        --notes-file "$RELEASE_NOTES" \
        "$DMG_FILE" \
        "$SHA_FILE" \
        "$APPCAST_FILE"
    step "Created GitHub release"
fi

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${APP_NAME}-${RELEASE_VERSION}.dmg"
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
APPCAST_TMP="$(mktemp -t dockishOS-live-appcast)"
APPCAST_OK=false
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsSL -H "Cache-Control: no-cache" "${APPCAST_URL}?t=$(date +%s)" -o "$APPCAST_TMP" \
        && grep -q "<sparkle:shortVersionString>${RELEASE_VERSION}</sparkle:shortVersionString>" "$APPCAST_TMP" \
        && grep -q "sparkle-signatures:" "$APPCAST_TMP"; then
        APPCAST_OK=true
        break
    fi
    step "Live appcast not ready — retry ${attempt}/10 in 3s"
    sleep 3
done
[ "$APPCAST_OK" = true ] || fail "Live appcast.xml at ${APPCAST_URL} did not propagate after 10 attempts"
step "Verified live signed appcast"

echo ""
info "Release complete"
echo "  Version:  v${RELEASE_VERSION} (build ${RELEASE_BUILD})"
echo "  App:      build/${APP_NAME}.app"
echo "  DMG:      ${DMG_FILE}"
echo "  Checksum: ${SHA_FILE}"
echo "  Release:  https://github.com/${GITHUB_REPO}/releases/tag/${RELEASE_TAG}"
echo "  Download: ${DOWNLOAD_URL}"
echo ""
