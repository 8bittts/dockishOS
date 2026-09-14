import XCTest

/// Regression guard for the v0.014 → v0.015 menu bar icon bug.
///
/// In v0.014 the status item icon source was swapped from the branded
/// mark to the generic `dock.rectangle` SF Symbol. The SF Symbol read as
/// "icon missing" in the menu bar.
///
/// The status item now uses a template silhouette of the branded mark so
/// the system can tint it on light and dark menu bars. This test fails if
/// the source reverts to `dock.rectangle` or to the full-color app icon.
final class MenuBarIconRegressionTests: XCTestCase {
    func testStatusItemUsesTemplateBrandedMark() throws {
        let source = try Self.menuBarControllerSource()

        XCTAssertTrue(
            source.contains("DockishBrandAssets.menuBarTemplateIcon(size: DockishBrandAssets.menuBarIconSize)"),
            "MenuBarController must source the status item from DockishBrandAssets.menuBarTemplateIcon."
        )

        XCTAssertFalse(
            source.contains("DockishBrandAssets.applicationIcon(size: DockishBrandAssets.menuBarIconSize)"),
            "The status item must not use the full-color application icon; HIG menu-bar extras are black-and-clear templates."
        )

        XCTAssertFalse(
            source.contains("dock.rectangle"),
            "MenuBarController must not reference the dock.rectangle SF Symbol for the status item."
        )
    }

    private static func menuBarControllerSource(file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile
            .deletingLastPathComponent() // DockishOSCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // repo root
        let menuBar = repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("DockishOS")
            .appendingPathComponent("MenuBarController.swift")
        return try String(contentsOf: menuBar, encoding: .utf8)
    }
}
