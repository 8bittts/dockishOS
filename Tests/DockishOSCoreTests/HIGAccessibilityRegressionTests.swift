import XCTest

/// Guards the HIG accessibility contracts that live in the app target.
final class HIGAccessibilityRegressionTests: XCTestCase {
    func testBarPanelCanBecomeKey() throws {
        let source = try Self.readSource("Sources/DockishOS/BarPanel.swift")
        XCTAssertTrue(
            source.contains("override var canBecomeKey: Bool { true }"),
            "BarPanel must be able to become key for VoiceOver and Full Keyboard Access."
        )
        XCTAssertFalse(
            source.contains("override var canBecomeKey: Bool { false }"),
            "BarPanel.canBecomeKey must not stay false."
        )
    }

    func testStatusMenuExposesSpaceSwitching() throws {
        let source = try Self.readSource("Sources/DockishOS/MenuBarController.swift")
        XCTAssertTrue(source.contains("Previous Space"), "Status menu must offer Previous Space.")
        XCTAssertTrue(source.contains("Next Space"), "Status menu must offer Next Space.")
        XCTAssertTrue(source.contains("adjacentSpace"), "Space menu items must use SpacesStore.adjacentSpace.")
    }

    func testCollapseHonorsReduceMotion() throws {
        let source = try Self.readSource("Sources/DockishOS/BarController.swift")
        XCTAssertTrue(
            source.contains("accessibilityDisplayShouldReduceMotion"),
            "Bar collapse/expand must honor Reduce Motion."
        )
    }

    func testHUDHonorsReduceTransparency() throws {
        let source = try Self.readSource("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(
            source.contains("accessibilityDisplayShouldReduceTransparency"),
            "HUD materials must honor Reduce Transparency."
        )
    }

    func testAccessibilityUsageDescriptionNamesBadges() throws {
        let source = try Self.readSource("Resources/Info.plist")
        XCTAssertTrue(
            source.contains("badge"),
            "NSAccessibilityUsageDescription must mention Dock badge counts."
        )
    }

    private static func readSource(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
