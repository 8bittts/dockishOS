import AppKit
import CoreGraphics

/// Private CoreGraphics SPI bindings for Spaces (a.k.a. virtual desktops).
///
/// macOS exposes no public API for Spaces. Every Spaces-aware tool on macOS
/// (Spaceman, AltTab, yabai, Mission Control Plus, …) uses these symbols
/// from the CGS (Core Graphics Services) sub-framework. They have been
/// stable from macOS 10.x through macOS 26 — Apple tolerates this usage,
/// but reserves the right to break it. Wrap every call in graceful
/// fallbacks; never crash on SPI failure.
typealias CGSConnectionID = Int32
typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> Unmanaged<CFArray>?

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString) -> CGSSpaceID

@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString, _ space: CGSSpaceID)

struct SpaceInfo: Identifiable, Hashable {
    let id: CGSSpaceID
    let displayUUID: String
    let index: Int          // 1-based, matches what Mission Control shows
    let isFullscreen: Bool  // type == 4
}

enum SpacesAPI {
    /// Returns Spaces grouped by display identifier, in Mission Control order.
    /// Filters out fullscreen-app spaces by default to keep the UI clean.
    static func allSpaces(includeFullscreen: Bool = false) -> [String: [SpaceInfo]] {
        let cid = CGSMainConnectionID()
        guard let raw = CGSCopyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return [:]
        }
        var result: [String: [SpaceInfo]] = [:]
        for displayDict in raw {
            guard
                let display = displayDict["Display Identifier"] as? String,
                let spaces = displayDict["Spaces"] as? [[String: Any]]
            else { continue }
            var entries: [SpaceInfo] = []
            var idx = 1
            for s in spaces {
                guard let id = s["ManagedSpaceID"] as? CGSSpaceID else { continue }
                let type = s["type"] as? Int ?? 0
                let isFs = (type == 4)
                if !includeFullscreen && isFs { continue }
                entries.append(SpaceInfo(id: id, displayUUID: display, index: idx, isFullscreen: isFs))
                idx += 1
            }
            result[display] = entries
        }
        return result
    }

    /// Current active Space ID for the given display.
    static func currentSpaceID(for displayUUID: String) -> CGSSpaceID {
        CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), displayUUID as CFString)
    }

    /// Switch the given display to the target Space.
    /// On macOS 14+ this is the closest thing to a one-call "go to space N".
    static func switchTo(_ space: SpaceInfo) {
        CGSManagedDisplaySetCurrentSpace(
            CGSMainConnectionID(),
            space.displayUUID as CFString,
            space.id
        )
    }

    /// Display identifier for an `NSScreen`. Falls back to "Main".
    static func displayUUID(for screen: NSScreen) -> String {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "Main"
        }
        let displayID = CGDirectDisplayID(num.uint32Value)
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return "Main"
        }
        return CFUUIDCreateString(nil, uuidRef) as String
    }
}
