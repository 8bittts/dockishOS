#!/usr/bin/env bash
#
# build_and_run.sh — Stage and launch a real .app bundle locally.
#
# `swift run DockishOS` works for most code paths, but a real .app bundle
# is required for: launchctl-style accessory apps, Info.plist behaviors
# (LSUIElement, NSAccessibilityUsageDescription, NSScreenCaptureUsage…),
# and any future Sparkle integration. This script builds the binary,
# assembles a bundle in build/local-run/DockishOS.app, and launches it.
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
LOCAL_RUN_DIR="${REPO_ROOT}/build/local-run"
APP_BUNDLE="${LOCAL_RUN_DIR}/${APP_NAME}.app"
APP_CONTENTS="${APP_BUNDLE}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"
APP_BINARY="${APP_MACOS}/${APP_NAME}"
INFO_PLIST="${APP_CONTENTS}/Info.plist"
ICONSET_DIR="${REPO_ROOT}/build/${APP_NAME}.iconset"
ICNS_FILE="${REPO_ROOT}/build/${APP_NAME}.icns"

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

/bin/rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -f "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "$APP_RESOURCES/${APP_NAME}.icns"
fi

cp "$SOURCE_PLIST" "$INFO_PLIST"
plist_set "$INFO_PLIST" "CFBundleIdentifier" string "$BUNDLE_ID"
plist_set "$INFO_PLIST" "CFBundleExecutable" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundleName" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundleDisplayName" string "$APP_NAME"
plist_set "$INFO_PLIST" "CFBundlePackageType" string "APPL"
plist_set "$INFO_PLIST" "CFBundleIconFile" string "$APP_NAME"
plist_set "$INFO_PLIST" "NSPrincipalClass" string "NSApplication"

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
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null && echo "OK ${APP_NAME} is running"
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--verify]" >&2
        exit 2
        ;;
esac
