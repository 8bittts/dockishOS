import XCTest

/// Guards the launcher and switcher contracts that only a running app can
/// show, each found by driving a built bundle on macOS 27.
final class PanelRegressionTests: XCTestCase {
    /// An activating panel depended on app activation the system can decline,
    /// and closed itself 40 ms after it opened.
    func testLauncherAndSwitcherPanelsDoNotActivateTheApp() throws {
        let source = try RepositorySource.read("Sources/DockishOS/HUDPanel.swift")
        XCTAssertTrue(
            source.contains("styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView]"),
            "HUDPanel must stay a non-activating panel."
        )
        XCTAssertFalse(
            source.contains("activateSelf"),
            "HUDPanel must not bring the app forward to take key focus."
        )
    }

    /// With default sizing options the hosting view shrank the launcher to
    /// its search field, so the results never showed.
    func testPanelsKeepTheirOwnSize() throws {
        let source = try RepositorySource.read("Sources/DockishOS/HUDPanel.swift")
        XCTAssertTrue(
            source.contains("host.sizingOptions = []"),
            "The hosting view must not resize the launcher or switcher panel."
        )
    }

    /// A row keyed by its index kept showing the app that held that index
    /// before the query changed.
    func testResultRowsAreNotIdentifiedByIndex() throws {
        for path in ["Sources/DockishOS/LauncherView.swift", "Sources/DockishOS/SwitcherView.swift"] {
            let source = try RepositorySource.read(path)
            XCTAssertFalse(source.contains(".id(index)"), "\(path) must identify rows by item, not by index.")
        }
    }

    /// SwiftUI key handlers need keyboard focus the switcher never has, so
    /// the arrow keys did nothing.
    func testSwitcherPanelHandlesItsKeys() throws {
        let panel = try RepositorySource.read("Sources/DockishOS/SwitcherController.swift")
        for key in ["kVK_Tab", "kVK_LeftArrow", "kVK_RightArrow", "kVK_Return", "kVK_Escape"] {
            XCTAssertTrue(panel.contains(key), "SwitcherPanel must handle \(key).")
        }
        let view = try RepositorySource.read("Sources/DockishOS/SwitcherView.swift")
        XCTAssertFalse(view.contains(".onKeyPress"), "SwitcherView must leave the keyboard to SwitcherPanel.")
    }
}
