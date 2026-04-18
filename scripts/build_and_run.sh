#!/usr/bin/env bash
#
# build_and_run.sh — Stage and launch a real .app bundle locally.
#
# `swift run DockishOS` works for most code paths, but a real .app bundle
# is required for: accessory-app launch behavior, Info.plist-backed
# settings like `LSUIElement` and `NSAccessibilityUsageDescription`, and
# Sparkle integration. This script builds the binary,
# assembles a bundle in build/DockishOS.app, and launches it. We keep the
# top-level .app path stable so macOS privacy permissions (Accessibility,
# login item registration, and Launch Services bookkeeping are less likely
# to treat each run as a different app.
#
# Usage:
#   ./scripts/build_and_run.sh                # launch
#   ./scripts/build_and_run.sh --logs         # launch + stream app logs
#   ./scripts/build_and_run.sh --debug        # launch under lldb
#   ./scripts/build_and_run.sh --verify       # launch and confirm process is alive

set -euo pipefail

MODE="${1:-run}"
APP_NAME="DockishOS"
BUNDLE_ID="com.8bittts.dockishos"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PLIST="${REPO_ROOT}/Resources/Info.plist"
LOCAL_RUN_DIR="${REPO_ROOT}/build"
APP_BUNDLE="${LOCAL_RUN_DIR}/${APP_NAME}.app"
APP_CONTENTS="${APP_BUNDLE}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"
APP_FRAMEWORKS="${APP_CONTENTS}/Frameworks"
APP_BINARY="${APP_MACOS}/${APP_NAME}"
INFO_PLIST="${APP_CONTENTS}/Info.plist"
ICONSET_DIR="${REPO_ROOT}/build/${APP_NAME}.iconset"
ICNS_FILE="${REPO_ROOT}/build/${APP_NAME}.icns"
SPARKLE_SOURCE="${REPO_ROOT}/tools/sparkle/Sparkle.framework"
ENTITLEMENTS="${REPO_ROOT}/DockishOS.entitlements"
CODESIGN_IDENTITY=""
CODESIGN_ARGS=()

resolve_signing_identity() {
    if [ -n "${DOCKISHOS_CODESIGN_IDENTITY:-}" ]; then
        CODESIGN_IDENTITY="$DOCKISHOS_CODESIGN_IDENTITY"
        return
    fi

    local identity
    identity="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed 's/.*"\(.*\)".*/\1/' || true)"

    if [ -n "$identity" ]; then
        CODESIGN_IDENTITY="$identity"
    else
        CODESIGN_IDENTITY="-"
    fi
}

codesign_base_args() {
    CODESIGN_ARGS=(--force --sign "$CODESIGN_IDENTITY")
    if [ "$CODESIGN_IDENTITY" != "-" ]; then
        CODESIGN_ARGS+=(--options runtime --timestamp)
    fi
}

sign_target() {
    local target="$1"
    local with_entitlements="${2:-false}"
    local args=("${CODESIGN_ARGS[@]}")
    if [ "$with_entitlements" = true ] && [ -f "$ENTITLEMENTS" ]; then
        args+=(--entitlements "$ENTITLEMENTS")
    fi
    codesign "${args[@]}" "$target"
}

sign_with_retry() {
    local target="$1"
    local with_entitlements="${2:-false}"
    local attempt=0
    local max_attempts=5
    while [ $attempt -lt $max_attempts ]; do
        if sign_target "$target" "$with_entitlements" >/dev/null 2>&1; then return 0; fi
        attempt=$((attempt + 1))
        sleep 1
    done
    echo "Signing failed after ${max_attempts} attempts: ${target}" >&2
    exit 1
}

plist_set() {
    local plist="$1" key="$2" type="$3" value="$4"
    if /usr/libexec/PlistBuddy -c "Print :${key}" "$plist" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$plist"
    else
        /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "$plist"
    fi
}

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$REPO_ROOT"
swift build

BUILD_BIN_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="${BUILD_BIN_DIR}/${APP_NAME}"

[ -f "$BUILD_BINARY" ]  || { echo "Missing app binary at ${BUILD_BINARY}" >&2; exit 1; }
[ -f "$SOURCE_PLIST" ]  || { echo "Missing source Info.plist at ${SOURCE_PLIST}" >&2; exit 1; }

swift scripts/generate-app-icon.swift >/dev/null
if [ -d "$ICONSET_DIR" ]; then
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
fi

mkdir -p "$APP_BUNDLE"
/bin/rm -rf "$APP_CONTENTS"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -f "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "$APP_RESOURCES/${APP_NAME}.icns"
fi

if [ -d "$SPARKLE_SOURCE" ]; then
    ditto "$SPARKLE_SOURCE" "$APP_FRAMEWORKS/Sparkle.framework"
fi

cp "$SOURCE_PLIST" "$INFO_PLIST"
plist_set "$INFO_PLIST" "CFBundleIdentifier" string "$BUNDLE_ID"
plist_set "$INFO_PLIST" "CFBundleExecutable" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundleName" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundleDisplayName" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundlePackageType" string "APPL"
plist_set "$INFO_PLIST" "CFBundleIconFile" string "$APP_NAME"
plist_set "$INFO_PLIST" "NSPrincipalClass" string "NSApplication"

resolve_signing_identity
codesign_base_args

if [ -d "$SPARKLE_SOURCE" ]; then
    SPARKLE_FW="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
    for nested in \
        "$SPARKLE_FW/Versions/B/XPCServices"/*.xpc \
        "$SPARKLE_FW/Versions/B/Autoupdate.app" \
        "$SPARKLE_FW/Versions/B/Autoupdate" \
        "$SPARKLE_FW/Versions/B/Updater.app"; do
        [ -e "$nested" ] || continue
        sign_with_retry "$nested" false
    done
    sign_with_retry "$SPARKLE_FW" false
fi

sign_with_retry "$APP_BUNDLE" true
codesign --verify --strict --verbose=2 "$APP_BUNDLE" >/dev/null

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"${APP_NAME}\""
        ;;
    --verify|verify)
        open_app
        for _ in $(seq 1 10); do
            if pid="$(pgrep -x "$APP_NAME" | tail -n 1)"; then
                echo "OK ${APP_NAME} is running (pid ${pid})"
                exit 0
            fi
            sleep 1
        done
        echo "ERROR: ${APP_NAME} did not stay running after launch" >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--verify]" >&2
        exit 2
        ;;
esac
