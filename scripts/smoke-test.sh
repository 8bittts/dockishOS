#!/usr/bin/env bash
#
# smoke-test.sh — Repository and release-artifact gate for DockishOS.
#
# Usage:
#   ./scripts/smoke-test.sh              # tests + build; artifact checks warn
#   ./scripts/smoke-test.sh --production # artifact checks must pass
#
# Fails closed: an absent artifact, an empty test run, or a missing
# notarization ticket is an error, never a silent pass.

set -euo pipefail

APP_NAME="DockishOS"
BUNDLE_ID="com.8bittts.dockishos"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRE_PRODUCTION=false

for arg in "$@"; do
    case "$arg" in
        --production) REQUIRE_PRODUCTION=true ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "usage: $0 [--production]" >&2; exit 2 ;;
    esac
done

cd "$REPO_ROOT"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
step() { printf "\033[1;36m  ->\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31mERROR:\033[0m %s\n" "$1" >&2; exit 1; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$1"; }

require_file() { [ -f "$1" ] || fail "Missing required file: $1"; }
require_dir()  { [ -d "$1" ] || fail "Missing required directory: $1"; }
require_executable() { [ -x "$1" ] || fail "Missing executable: $1"; }

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }

assert_plist_value() {
    local plist="$1" key="$2" expected="$3" actual
    actual="$(plist_value "$plist" "$key")"
    [ "$actual" = "$expected" ] || fail "${plist} ${key}: expected '${expected}', got '${actual}'"
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain $2"
}

verify_app_bundle_shape() {
    local app="$1"
    local plist="${app}/Contents/Info.plist"
    local binary="${app}/Contents/MacOS/${APP_NAME}"

    require_dir "$app"
    require_file "$plist"
    require_executable "$binary"
    require_dir "${app}/Contents/Frameworks/Sparkle.framework"
    # The 0.014/0.015 regression shipped a Sparkle framework without its
    # installer helper, which broke in-app updates with a generic error.
    require_dir "${app}/Contents/Frameworks/Sparkle.framework/Versions/Current/Updater.app"
    require_dir "${app}/Contents/Frameworks/Sparkle.framework/Versions/Current/XPCServices/Installer.xpc"
    require_dir "${app}/Contents/Frameworks/Sparkle.framework/Versions/Current/XPCServices/Downloader.xpc"

    assert_plist_value "$plist" "CFBundleIdentifier" "$BUNDLE_ID"
    assert_plist_value "$plist" "CFBundleExecutable" "$APP_NAME"
    assert_plist_value "$plist" "CFBundlePackageType" "APPL"
    assert_plist_value "$plist" "SURequireSignedFeed" "true"
    assert_plist_value "$plist" "SUVerifyUpdateBeforeExtraction" "true"

    otool -L "$binary" | grep -q "@rpath/Sparkle.framework" \
        || fail "${binary} is not linked to bundled Sparkle via @rpath"
}

verify_release_artifacts() {
    local version="$1" build_number="$2"
    local app="build/${APP_NAME}.app"
    local plist="${app}/Contents/Info.plist"
    local dmg="build/${APP_NAME}-${version}.dmg"
    local sha_file="build/${APP_NAME}-${version}.sha256"
    local appcast="build/appcast.xml"

    verify_app_bundle_shape "$app"
    assert_plist_value "$plist" "CFBundleShortVersionString" "$version"
    assert_plist_value "$plist" "CFBundleVersion" "$build_number"
    require_file "$dmg"
    require_file "$sha_file"
    require_file "$appcast"

    codesign --verify --strict --deep "$app" >/dev/null 2>&1 \
        || fail "Release app signature verification failed"
    step "Release app signature verified"

    if spctl -a -vv "$app" >/dev/null 2>&1; then
        step "Release app accepted by Gatekeeper"
    else
        [ "$REQUIRE_PRODUCTION" = false ] || fail "Release app rejected by Gatekeeper"
        warn "Release app was not accepted by Gatekeeper"
    fi

    codesign -dvvv "$dmg" >/dev/null 2>&1 || fail "DMG is not signed"
    if spctl -a -vv -t open --context context:primary-signature "$dmg" >/dev/null 2>&1; then
        step "DMG accepted by Gatekeeper"
    else
        [ "$REQUIRE_PRODUCTION" = false ] || fail "DMG rejected by Gatekeeper"
        warn "DMG was not accepted by Gatekeeper"
    fi

    # A missing notary keychain profile only warns inside build-dmg.sh, so
    # this is what stops an un-notarized DMG from reaching users.
    if xcrun stapler validate "$dmg" >/dev/null 2>&1; then
        step "DMG notarization ticket verified"
    else
        [ "$REQUIRE_PRODUCTION" = false ] || fail "DMG notarization ticket missing or invalid"
        warn "DMG notarization ticket missing or invalid"
    fi

    local expected actual
    expected="$(awk '{print $1}' "$sha_file")"
    actual="$(shasum -a 256 "$dmg" | awk '{print $1}')"
    [ -n "$expected" ] || fail "Empty checksum in ${sha_file}"
    [ "$expected" = "$actual" ] || fail "DMG checksum mismatch"
    step "DMG checksum verified"

    local dmg_bytes
    dmg_bytes="$(stat -f%z "$dmg")"
    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$appcast"
    fi
    assert_contains "$appcast" "<sparkle:shortVersionString>${version}</sparkle:shortVersionString>"
    assert_contains "$appcast" "<sparkle:version>${build_number}</sparkle:version>"
    assert_contains "$appcast" "${APP_NAME}-${version}.dmg"
    assert_contains "$appcast" "length=\"${dmg_bytes}\""
    assert_contains "$appcast" "sparkle-signatures:"
    assert_contains "$appcast" "sparkle:edSignature="
    # The embedded EdDSA signature covers the exact byte length, so verify it
    # rather than only grepping for the marker comment.
    require_executable "tools/sparkle/bin/sign_update"
    tools/sparkle/bin/sign_update --verify "$appcast" >/dev/null 2>&1 \
        || fail "Sparkle appcast signature verification failed"
    step "Signed appcast metadata verified"
}

info "Checking repository smoke-test inputs"
require_file "Package.swift"
require_file "Resources/Info.plist"
require_file "tools/sparkle/VERSION"
require_dir "tools/sparkle/Sparkle.framework"
step "Repository inputs present"

info "Running automated tests"
TEST_LOG="$(mktemp -t dockishOS-smoke-tests)"
trap 'rm -f "$TEST_LOG"' EXIT
swift test 2>&1 | tee "$TEST_LOG"

# `swift test` exits 0 when it runs nothing at all, so assert a positive
# executed count instead of reading the absence of a failure as a pass.
# XCTest prints a per-suite line and a grand total, so take the largest
# count rather than summing nested totals.
EXECUTED="$(awk '
    match($0, /Executed [0-9]+ test/) {
        s = substr($0, RSTART + 9)
        sub(/ .*/, "", s)
        if (s + 0 > max) max = s + 0
    }
    END { print max + 0 }
' "$TEST_LOG")"
[ "$EXECUTED" -gt 0 ] || fail "swift test reported no executed tests; the suite did not run"
step "Tests passed (${EXECUTED} XCTest cases executed)"

info "Building release binary"
swift build -c release
step "Release build succeeded"

# The release flow verifies artifacts before it bumps the source plist, so
# it passes the version being shipped explicitly.
VERSION="${DOCKISHOS_VERSION:-$(plist_value Resources/Info.plist CFBundleShortVersionString)}"
BUILD_NUMBER="${DOCKISHOS_BUILD:-$(plist_value Resources/Info.plist CFBundleVersion)}"

if [ -d "build/${APP_NAME}.app" ] || [ "$REQUIRE_PRODUCTION" = true ]; then
    info "Verifying release artifacts for v${VERSION} (build ${BUILD_NUMBER})"
    verify_release_artifacts "$VERSION" "$BUILD_NUMBER"
else
    warn "No build/${APP_NAME}.app present; skipping release artifact checks"
fi

echo ""
info "Smoke test complete"
