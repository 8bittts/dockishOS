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

    /// The status menu enables its items automatically, so a Space command
    /// is only disabled at an end through menu validation.
    func testSpaceCommandsAreValidated() throws {
        let source = try RepositorySource.read("Sources/DockishOS/MenuBarController.swift")
        XCTAssertTrue(source.contains("NSMenuItemValidation"))
        XCTAssertTrue(source.contains("func validateMenuItem"))
    }

    func testStatusMenuExposesSpaceSwitching() throws {
        let source = try RepositorySource.read("Sources/DockishOS/MenuBarController.swift")
        XCTAssertTrue(source.contains("Previous Space"), "Status menu must offer Previous Space.")
        XCTAssertTrue(source.contains("Next Space"), "Status menu must offer Next Space.")
        XCTAssertTrue(source.contains("adjacentSpace"), "Space menu items must use SpacesAPI.adjacentSpace.")
    }

    func testCollapseHonorsReduceMotion() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarController.swift")
        XCTAssertTrue(
            source.contains("accessibilityDisplayShouldReduceMotion"),
            "Bar collapse/expand must honor Reduce Motion."
        )
    }
}
