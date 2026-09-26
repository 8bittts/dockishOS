// swift-tools-version:5.10
import Foundation
import PackageDescription

// [CRITICAL] The Sparkle framework search path must be ABSOLUTE.
//
// `-F tools/sparkle` was relative, which only resolved while the compiler inherited the package
// root as its working directory. Swift 6.4 / Xcode 27 build through the Xcode build engine
// (`.build/manifest.pif`, `.build/out/Intermediates.noindex`), and that engine passes
// `-working-directory <parent of the package>` to swiftc. The relative path then resolved to
// `../tools/sparkle`, which does not exist, and every build failed with
// `unable to resolve module dependency: 'Sparkle'` even though the vendored framework was intact
// and matched its VERSION pin.
//
// Anchor to this manifest instead of to a working directory nothing here controls. `#filePath` is
// the absolute path of this file, so the search path follows the checkout — including a worktree
// at a different path — and never depends on where the build is launched from.
let sparkleSearchPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("tools/sparkle")
    .path

let package = Package(
    name: "DockishOS",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DockishOSCore",
            path: "Sources/DockishOSCore"
        ),
        .executableTarget(
            name: "DockishOS",
            dependencies: ["DockishOSCore"],
            path: "Sources/DockishOS",
            swiftSettings: [
                .unsafeFlags(["-F", sparkleSearchPath]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", sparkleSearchPath,
                    "-framework", "Sparkle",
                    // Production: framework in Contents/Frameworks of the .app
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks",
                    // Dev: tools/sparkle relative to .build/debug/DockishOS
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../tools/sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../tools/sparkle",
                ]),
            ]
        ),
        .testTarget(
            name: "DockishOSCoreTests",
            dependencies: ["DockishOSCore"],
            path: "Tests/DockishOSCoreTests"
        )
    ]
)
