import AppKit
import DockishOSCore

typealias CGSSpaceID = UInt64

/// One Space (virtual desktop) of one display.
struct SpaceInfo: Hashable {
    let id: CGSSpaceID
    /// The window server's key for the display: its UUID, or "Main" when
    /// displays share one set of Spaces.
    let displayIdentifier: String
}

/// Private CoreGraphics SPI for Spaces (a.k.a. virtual desktops).
///
/// macOS exposes no public API for Spaces, so this uses the CGS (Core Graphics
/// Services) calls. Apple can remove them in any release: every symbol is
/// resolved at run time, and Space switching turns itself off when one is missing.
@MainActor
enum SpacesAPI {
    private typealias ConnectionID = Int32

    private static let mainConnectionID = privateSymbol(
        "CGSMainConnectionID",
        as: (@convention(c) () -> ConnectionID).self
    )
    private static let copyManagedDisplaySpaces = privateSymbol(
        "CGSCopyManagedDisplaySpaces",
        as: (@convention(c) (ConnectionID) -> Unmanaged<CFArray>?).self
    )
    private static let getCurrentSpace = privateSymbol(
        "CGSManagedDisplayGetCurrentSpace",
        as: (@convention(c) (ConnectionID, CFString) -> CGSSpaceID).self
    )
    private static let setCurrentSpace = privateSymbol(
        "CGSManagedDisplaySetCurrentSpace",
        as: (@convention(c) (ConnectionID, CFString, CGSSpaceID) -> Void).self
    )

    /// The window server's `type` for a Space that holds a fullscreen app.
    private static let fullscreenSpaceType = 4

    /// The Space before (`direction` -1) or after (+1) the active one on
    /// `screen`. Returns `nil` at either end — Space switching does not wrap —
    /// and while the active Space is a fullscreen app.
    static func adjacentSpace(for screen: NSScreen, direction: Int) -> SpaceInfo? {
        guard let mainConnectionID, let getCurrentSpace else { return nil }
        let spacesByDisplay = desktopSpacesByDisplay()
        // The screen's UUID is not a key when displays share one set of
        // Spaces, so fall back to the entry that exists.
        guard
            let spaces = spacesByDisplay[screen.displayUUID] ?? spacesByDisplay.values.first,
            let display = spaces.first?.displayIdentifier
        else { return nil }
        let currentID = getCurrentSpace(mainConnectionID(), display as CFString)
        guard
            let index = spaces.firstIndex(where: { $0.id == currentID }),
            let adjacent = BoundedIndex.moving(index, by: direction, count: spaces.count)
        else { return nil }
        return spaces[adjacent]
    }

    /// Switches the Space's display to it.
    static func switchTo(_ space: SpaceInfo) {
        guard let mainConnectionID, let setCurrentSpace else { return }
        setCurrentSpace(mainConnectionID(), space.displayIdentifier as CFString, space.id)
    }

    /// Desktop Spaces per display, in Mission Control order. Leaves out
    /// fullscreen-app Spaces, which are not places a user switches to by index.
    private static func desktopSpacesByDisplay() -> [String: [SpaceInfo]] {
        guard
            let mainConnectionID,
            let copyManagedDisplaySpaces,
            let displays = copyManagedDisplaySpaces(mainConnectionID())?.takeRetainedValue() as? [[String: Any]]
        else {
            Diagnostics.spaces.fault("CGS Spaces query failed; Space switching is off")
            return [:]
        }
        var result: [String: [SpaceInfo]] = [:]
        for display in displays {
            guard
                let identifier = display["Display Identifier"] as? String,
                let spaces = display["Spaces"] as? [[String: Any]]
            else { continue }
            result[identifier] = spaces.compactMap { space in
                guard
                    let id = space["ManagedSpaceID"] as? CGSSpaceID,
                    space["type"] as? Int != fullscreenSpaceType
                else { return nil }
                return SpaceInfo(id: id, displayIdentifier: identifier)
            }
        }
        return result
    }
}
