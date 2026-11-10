import XCTest

final class HIGChromeRegressionTests: XCTestCase {
    func testAppIconGeneratorDoesNotBakeASquircle() throws {
        let source = try RepositorySource.read("scripts/generate-app-icon.swift")
        XCTAssertTrue(
            source.contains("Full-bleed square"),
            "The icon generator must document that the asset is an unmasked square."
        )
        XCTAssertFalse(
            source.contains("addClip()"),
            "The icon generator must not clip the mark to a baked squircle."
        )
    }

    func testSettingsWindowOmitsMiniaturizeAndZoom() throws {
        let source = try RepositorySource.read("Sources/DockishOS/SettingsController.swift")
        XCTAssertTrue(
            source.contains("styleMask: [.titled, .closable]"),
            "Settings must not offer miniaturize or zoom."
        )
        XCTAssertFalse(
            source.contains(".miniaturizable"),
            "Settings must not be miniaturizable."
        )
    }

    /// The floating surfaces are the system's Liquid Glass, and nothing
    /// rebuilds glass or a material by hand.
    func testFloatingSurfaceIsSystemGlass() throws {
        let support = try RepositorySource.read("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(support.contains("glassEffect("), "The floating surface must use glassEffect.")
        for path in ["BarView.swift", "CollapsedBarTab.swift", "SwitcherView.swift"] {
            let source = try RepositorySource.read("Sources/DockishOS/\(path)")
            XCTAssertTrue(source.contains(".floatingSurface("), "\(path) must use the shared floating surface.")
        }
        for name in try RepositorySource.appSourceNames() {
            let source = try RepositorySource.read("Sources/DockishOS/\(name)")
            XCTAssertFalse(source.contains("NSVisualEffectView"), "\(name) must not fall back to a visual effect view.")
            XCTAssertFalse(source.contains("LinearGradient"), "\(name) must not draw its own highlights.")
            XCTAssertFalse(source.contains("#available"), "\(name) must not branch on a macOS version below the minimum.")
        }
    }

    /// Liquid Glass needs macOS 26, so every place that declares the minimum
    /// must agree, or Sparkle offers the update to a Mac that cannot run it.
    func testMinimumSystemVersionIsMacOS26Everywhere() throws {
        XCTAssertTrue(try RepositorySource.read("Package.swift").contains("platforms: [.macOS(.v26)]"))
        XCTAssertTrue(
            try RepositorySource.read("Resources/Info.plist")
                .contains("<key>LSMinimumSystemVersion</key>\n\t<string>26.0</string>"),
            "Sparkle's generate_appcast reads the appcast's minimum system version from this key."
        )
    }

    func testNotificationBadgeUsesSystemRed() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(
            source.contains("Color(nsColor: .systemRed)"),
            "Notification badges must use systemRed."
        )
        XCTAssertFalse(
            source.contains("Capsule().fill(Color.red)"),
            "Notification badges must not use hardcoded Color.red."
        )
    }
}
