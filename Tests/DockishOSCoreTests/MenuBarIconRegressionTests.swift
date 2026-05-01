import XCTest

/// Regression guard for the v0.014 → v0.015 menu bar icon bug.
///
/// In v0.014 the status item icon source was swapped from the bundled
/// DockishOS.icns (`DockishBrandAssets.applicationIcon`) to the generic
/// `dock.rectangle` SF Symbol (`DockishBrandAssets.menuBarIcon`). The
/// SF Symbol read as "icon missing" in the menu bar.
///
/// This test fails if anyone re-introduces the swap, or if the icon source
/// silently changes to a different SF Symbol path. If you intentionally
/// change the menu bar icon strategy, update both this test and CHANGELOG.
final class MenuBarIconRegressionTests: XCTestCase {
    func testStatusItemUsesBundledApplicationIcon() throws {
        let source = try Self.menuBarControllerSource()

        XCTAssertTrue(
            source.contains("DockishBrandAssets.applicationIcon(size: DockishBrandAssets.menuBarIconSize)"),
            "MenuBarController must source the status item icon from the bundled DockishOS.icns via DockishBrandAssets.applicationIcon — see CHANGELOG v0.015."
        )

        XCTAssertFalse(
            source.contains("DockishBrandAssets.menuBarIcon(size: DockishBrandAssets.menuBarIconSize)"),
            "MenuBarController must not assign the generic SF Symbol menuBarIcon to the status item — that regressed in v0.014 and shipped a placeholder-looking icon."
        )

        XCTAssertFalse(
            source.contains("dock.rectangle"),
            "MenuBarController must not reference the dock.rectangle SF Symbol for the status item — keep the branded .icns."
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
