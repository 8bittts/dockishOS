import XCTest
@testable import DockishOSCore

final class HotkeyMaskTests: XCTestCase {
    func testCarbonMaskMapsEachSupportedModifier() {
        XCTAssertEqual(HotkeyMask.carbonMask(command: true, option: false, control: false, shift: false), 1 << 8)
        XCTAssertEqual(HotkeyMask.carbonMask(command: false, option: false, control: false, shift: true), 1 << 9)
        XCTAssertEqual(HotkeyMask.carbonMask(command: false, option: true, control: false, shift: false), 1 << 11)
        XCTAssertEqual(HotkeyMask.carbonMask(command: false, option: false, control: true, shift: false), 1 << 12)
    }

    func testCarbonMaskCombinesModifiers() {
        XCTAssertEqual(
            HotkeyMask.carbonMask(command: true, option: true, control: true, shift: true),
            (1 << 8) | (1 << 9) | (1 << 11) | (1 << 12)
        )
    }
}
