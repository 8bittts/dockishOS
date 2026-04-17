// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DockishOS",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DockishOS",
            path: "Sources/DockishOS",
            swiftSettings: [
                .unsafeFlags(["-F", "tools/sparkle"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "tools/sparkle",
                    "-framework", "Sparkle",
                    // Production: framework in Contents/Frameworks of the .app
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks",
                    // Dev: tools/sparkle relative to .build/debug/DockishOS
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../tools/sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../tools/sparkle",
                ]),
            ]
        )
    ]
)
