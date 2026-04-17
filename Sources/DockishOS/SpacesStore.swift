import AppKit
import Combine

/// Observable model of Spaces grouped by display.
/// Refreshes on `activeSpaceDidChangeNotification` plus a 5s polling
/// interval (Spaces add/remove emits no public notification).
final class SpacesStore: ObservableObject {
    static let shared = SpacesStore()

    @Published private(set) var spacesByDisplay: [String: [SpaceInfo]] = [:]
    @Published private(set) var currentByDisplay: [String: CGSSpaceID] = [:]

    private var timer: Timer?
    private var spaceObserver: NSObjectProtocol?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let next = SpacesAPI.allSpaces()
        var current: [String: CGSSpaceID] = [:]
        for displayUUID in next.keys {
            current[displayUUID] = SpacesAPI.currentSpaceID(for: displayUUID)
        }
        if next != spacesByDisplay { spacesByDisplay = next }
        if current != currentByDisplay { currentByDisplay = current }
    }

    func spaces(for screen: NSScreen) -> [SpaceInfo] {
        let uuid = SpacesAPI.displayUUID(for: screen)
        if let s = spacesByDisplay[uuid], !s.isEmpty { return s }
        // Fallback when Spaces don't separate per display: use first display.
        return spacesByDisplay.values.sorted { ($0.first?.index ?? 0) < ($1.first?.index ?? 0) }.first ?? []
    }

    func currentSpaceID(for screen: NSScreen) -> CGSSpaceID? {
        let uuid = SpacesAPI.displayUUID(for: screen)
        return currentByDisplay[uuid] ?? currentByDisplay.values.first
    }

    func switchTo(_ space: SpaceInfo) {
        SpacesAPI.switchTo(space)
        // Optimistic local update; next notification refreshes truth.
        currentByDisplay[space.displayUUID] = space.id
    }
}
