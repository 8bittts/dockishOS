import XCTest
@testable import DockishOSCore

final class WindowEligibilityTests: XCTestCase {
    private func shows(layer: Int = 0, alpha: Double = 1, regular: Bool = true, own: Bool = false) -> Bool {
        WindowEligibility.showsChip(layer: layer, alpha: alpha, ownerIsRegularApp: regular, ownerIsThisApp: own)
    }

    func testARegularAppsVisibleNormalWindowShows() {
        XCTAssertTrue(shows())
    }

    /// WindowManager and other agents own layer-0 windows but are not apps the user switches to.
    func testASystemAgentsWindowDoesNotShow() {
        XCTAssertFalse(shows(regular: false))
    }

    func testAnInvisibleWindowDoesNotShow() {
        XCTAssertFalse(shows(alpha: 0))
    }

    func testAPanelOrMenuLayerDoesNotShow() {
        XCTAssertFalse(shows(layer: 3))
        XCTAssertFalse(shows(layer: 25))
    }

    func testThisAppsOwnWindowsDoNotShow() {
        XCTAssertFalse(shows(own: true))
    }
}
