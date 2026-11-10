import XCTest

/// Guards the app switcher contracts that only a running app can show, each
/// found by driving a built bundle on macOS 27.
final class PanelRegressionTests: XCTestCase {
    private func switcherSource() throws -> String {
        try RepositorySource.read("Sources/DockishOS/SwitcherController.swift")
    }

    /// An activating panel depended on app activation the system can decline,
    /// and closed itself 40 ms after it opened.
    func testSwitcherPanelDoesNotActivateTheApp() throws {
        let source = try switcherSource()
        XCTAssertTrue(
            source.contains("styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView]"),
            "SwitcherPanel must stay a non-activating panel."
        )
        XCTAssertFalse(
            source.contains("activateSelf"),
            "SwitcherPanel must not bring the app forward to take key focus."
        )
    }

    /// With default sizing options the hosting view resized the panel to the
    /// content's smallest size.
    func testSwitcherPanelKeepsItsOwnSize() throws {
        XCTAssertTrue(
            try switcherSource().contains("host.sizingOptions = []"),
            "The hosting view must not resize the switcher panel."
        )
    }

    /// A row keyed by its index keeps showing the item that held that index
    /// before the list changed.
    func testSwitcherTilesAreNotIdentifiedByIndex() throws {
        let source = try RepositorySource.read("Sources/DockishOS/SwitcherView.swift")
        XCTAssertFalse(source.contains(".id(index)"), "Identify tiles by window, not by index.")
    }

    /// SwiftUI key handlers need keyboard focus the switcher never has, so
    /// the arrow keys did nothing.
    func testSwitcherPanelHandlesItsKeys() throws {
        let panel = try switcherSource()
        for key in ["kVK_Tab", "kVK_LeftArrow", "kVK_RightArrow", "kVK_Return", "kVK_Escape"] {
            XCTAssertTrue(panel.contains(key), "SwitcherPanel must handle \(key).")
        }
        let view = try RepositorySource.read("Sources/DockishOS/SwitcherView.swift")
        XCTAssertFalse(view.contains(".onKeyPress"), "SwitcherView must leave the keyboard to SwitcherPanel.")
    }
}
