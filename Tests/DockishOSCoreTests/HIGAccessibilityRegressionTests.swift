import XCTest

/// Guards the HIG accessibility contracts that live in the app target.
final class HIGAccessibilityRegressionTests: XCTestCase {
    func testBarPanelCanBecomeKey() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarPanel.swift")
        XCTAssertTrue(
            source.contains("override var canBecomeKey: Bool { true }"),
            "BarPanel must be able to become key for VoiceOver and Full Keyboard Access."
        )
        XCTAssertFalse(
            source.contains("override var canBecomeKey: Bool { false }"),
            "BarPanel.canBecomeKey must not stay false."
        )
    }

    /// `accessibilityElement(children: .ignore)` on a chip button replaced the
    /// button with an element that had no press action and no button role.
    func testChipsStayButtonsForAssistiveClients() throws {
        for path in ["Sources/DockishOS/WindowChips.swift", "Sources/DockishOS/PinnedRow.swift"] {
            let source = try RepositorySource.read(path)
            XCTAssertFalse(
                source.contains(".accessibilityElement(children: .ignore)"),
                "\(path): a chip must stay a button so VoiceOver can press it."
            )
        }
    }

    /// The status menu is About, YEN Terminal, Settings, the project page,
    /// updates and Quit, in that order. Bar and Space commands are not in it.
    func testStatusMenuHoldsOnlyTheAppCommands() throws {
        let source = try RepositorySource.read("Sources/DockishOS/MenuBarController.swift")
        let titles = ["\"About DockishOS\"", "\"YEN Terminal\"", "\"Settings…\"", "\"GitHub Project\"",
                      "\"Check for Updates…\"", "\"Quit DockishOS\""]
        let positions = try titles.map { try XCTUnwrap(source.range(of: $0)?.lowerBound, "\($0) is missing") }
        XCTAssertEqual(positions, positions.sorted(), "The menu items are out of order.")
        for removed in ["Previous Space", "Next Space", "Collapse Bar", "Edge Tab", "on GitHub"] {
            XCTAssertFalse(source.contains(removed), "\(removed) no longer belongs in the status menu.")
        }
        XCTAssertTrue(try RepositorySource.read("Sources/DockishOS/AppLinks.swift").contains("https://yen.chat"))
    }

    func testCollapseHonorsReduceMotion() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarController.swift")
        XCTAssertTrue(
            source.contains("accessibilityDisplayShouldReduceMotion"),
            "Bar collapse/expand must honor Reduce Motion."
        )
    }
}
