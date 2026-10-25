# Security

Permissions, private API exposure, code signing and update-feed trust for DockishOS.

## Permissions

DockishOS asks for Accessibility only when a feature needs it: raising or closing a specific window, and reading optional notification badge text from the Dock accessibility tree.
Window listing and Spaces switching need no Screen Recording permission.
Notification badges are off by default; they rely on an undocumented Dock accessibility attribute and may stop working on a future macOS release.
`Resources/Info.plist` carries the Accessibility usage description, which names badge reading as well as raise and close.
`DockishOS.entitlements` declares no entitlements, so the app is not sandboxed; it needs private CoreGraphics Spaces APIs and Accessibility control.

## Private APIs

Spaces listing and switching use private CGS SPIs (`SpacesAPI`), so each macOS release can change them; the unit-tested core stays free of them and the app target isolates the calls.

## Signing and notarization

Release DMGs are signed with a Developer ID certificate and notarized through `scripts/build-dmg.sh`; `--local` skips notarization and `--unsigned` signs ad hoc.
Local builds are not notarized, so macOS can show the unidentified-developer warning on first launch; the README tells users how to open them.
`./scripts/smoke-test.sh --production` verifies the signature, the stapled notarization ticket, the DMG checksum and the signed appcast before a release ([09-quality.md](09-quality.md)).

## Update feed

Sparkle requires a signed feed (`SURequireSignedFeed`) and verifies each update before extraction (`SUVerifyUpdateBeforeExtraction`); the EdDSA public key lives in `Resources/Info.plist` under `SUPublicEDKey` and the private key in the developer's login keychain.
The committed `appcast.xml` carries an EdDSA signature over its exact byte length, so it is never hand-edited; `AGENTS.md` carries that rule and [05-infrastructure.md](05-infrastructure.md) the regeneration procedure.
The vendored framework is pinned by version, build, binary SHA-256 and required helper paths in `tools/sparkle/VERSION`, and the build preflight refuses a framework that drifts from the pin.

## Local data

Pinned apps and preferences persist in user defaults through `PinnedAppsStore` and `Settings`; the app collects no analytics and sends nothing but the Sparkle feed request.
