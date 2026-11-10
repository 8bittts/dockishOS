import XCTest

final class HIGWritingRegressionTests: XCTestCase {
    func testPinCommandsShareOnePair() throws {
        let chips = try RepositorySource.read("Sources/DockishOS/WindowChips.swift")
        let pinned = try RepositorySource.read("Sources/DockishOS/PinnedRow.swift")
        for source in [chips, pinned] {
            XCTAssertFalse(source.contains("Pin App to Bar"), "Use Pin to Bar, not Pin App to Bar.")
            XCTAssertFalse(source.contains("Unpin App from Bar"), "Use Unpin from Bar, not Unpin App from Bar.")
        }
        XCTAssertTrue(chips.contains("Pin to Bar"))
        XCTAssertTrue(chips.contains("Unpin from Bar"))
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
    }

    /// The bar and the switcher share one empty-state sentence, and Space is
    /// capitalized as macOS writes it.
    func testEmptyStatesShareOneSentence() throws {
        for path in ["Sources/DockishOS/WindowChips.swift", "Sources/DockishOS/SwitcherView.swift"] {
            XCTAssertTrue(
                try RepositorySource.read(path).contains("\"No windows in this Space\""),
                "\(path) must use the shared empty-state sentence."
            )
        }
    }

    /// Text uses system text styles, never a literal point size, and the
    /// interface says "shortcut" where code says hotkey.
    func testTypographyAndTermsAreNormalized() throws {
        for name in try RepositorySource.appSourceNames() {
            let source = try RepositorySource.read("Sources/DockishOS/\(name)")
            XCTAssertFalse(source.contains(".system(size:"), "\(name) sets a literal font size.")
            // A string literal that says hotkey is a stored key, never copy.
            let literals = source.matches(of: /"[^"\n]*[Hh]otkey[^"\n]*"/).map { String($0.output) }
            XCTAssertEqual(
                literals.filter { !$0.contains("DockishOS.") }, [],
                "\(name) shows the word hotkey to the user."
            )
        }
    }
}
