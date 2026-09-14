import XCTest

final class HIGChromeRegressionTests: XCTestCase {
    func testAppIconGeneratorDoesNotBakeASquircle() throws {
        let source = try Self.readSource("scripts/generate-app-icon.swift")
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
        let source = try Self.readSource("Sources/DockishOS/SettingsController.swift")
        XCTAssertTrue(
            source.contains("styleMask: [.titled, .closable]"),
            "Settings must not offer miniaturize or zoom."
        )
        XCTAssertFalse(
            source.contains(".miniaturizable"),
            "Settings must not be miniaturizable."
        )
    }

    func testNotificationBadgeUsesSystemRed() throws {
        let source = try Self.readSource("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(
            source.contains("Color(nsColor: .systemRed)"),
            "Notification badges must use systemRed."
        )
        XCTAssertFalse(
            source.contains("Capsule().fill(Color.red)"),
            "Notification badges must not use hardcoded Color.red."
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
