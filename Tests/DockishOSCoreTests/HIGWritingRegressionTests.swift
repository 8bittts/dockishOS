import XCTest

final class HIGWritingRegressionTests: XCTestCase {
    func testPinCommandsShareOnePair() throws {
        let chips = try RepositorySource.read("Sources/DockishOS/WindowChips.swift")
        let launcher = try RepositorySource.read("Sources/DockishOS/LauncherView.swift")
        let pinned = try RepositorySource.read("Sources/DockishOS/PinnedRow.swift")
        for source in [chips, launcher, pinned] {
            XCTAssertFalse(source.contains("Pin App to Bar"), "Use Pin to Bar, not Pin App to Bar.")
            XCTAssertFalse(source.contains("Unpin App from Bar"), "Use Unpin from Bar, not Unpin App from Bar.")
        }
        XCTAssertTrue(chips.contains("Pin to Bar"))
        XCTAssertTrue(chips.contains("Unpin from Bar"))
        XCTAssertTrue(launcher.contains("Pin to Bar"))
        XCTAssertTrue(launcher.contains("Unpin from Bar"))
        XCTAssertTrue(pinned.contains("Unpin from Bar"))
    }

    func testUnpinIsNotDestructive() throws {
        let chips = try RepositorySource.read("Sources/DockishOS/WindowChips.swift")
        XCTAssertFalse(
            chips.contains("Button(role: .destructive) { onTogglePin() }"),
            "Unpin must not use the destructive role."
        )
    }

    func testHotkeyWarningOmitsRawOSStatus() throws {
        let source = try RepositorySource.read("Sources/DockishOS/MenuBarController.swift")
        XCTAssertFalse(
            source.contains("OSStatus \\(status)"),
            "Hotkey conflict copy must not include a raw OSStatus."
        )
    }

    func testEmptyWindowTitleIsUntitled() throws {
        let source = try RepositorySource.read("Sources/DockishOS/WindowChips.swift")
        XCTAssertTrue(source.contains("\"Untitled\""))
        XCTAssertFalse(source.contains("(untitled)"))
        XCTAssertTrue(source.contains("No open apps in this space…"))
        XCTAssertFalse(source.contains("No open apps in this space..."))
    }
}
