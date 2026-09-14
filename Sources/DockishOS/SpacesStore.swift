import AppKit
import Combine
import DockishOSCore

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

    /// Deterministic fallback display (lowest first-space index) used when a
    /// screen's UUID isn't keyed. Both `spaces(for:)` and `currentSpaceID(for:)`
    /// resolve through the SAME display so the scroll-to-switch index lookup in
    /// `BarController.handleVerticalScroll` can't silently miss.
    private var fallbackDisplayUUID: String? {
        spacesByDisplay.min { ($0.value.first?.index ?? 0) < ($1.value.first?.index ?? 0) }?.key
    }

    func spaces(for screen: NSScreen) -> [SpaceInfo] {
        let uuid = SpacesAPI.displayUUID(for: screen)
        if let s = spacesByDisplay[uuid], !s.isEmpty { return s }
        guard let fallback = fallbackDisplayUUID else { return [] }
        return spacesByDisplay[fallback] ?? []
    }

    func currentSpaceID(for screen: NSScreen) -> CGSSpaceID? {
        let uuid = SpacesAPI.displayUUID(for: screen)
        if let id = currentByDisplay[uuid] { return id }
        guard let fallback = fallbackDisplayUUID else { return currentByDisplay.values.first }
        return currentByDisplay[fallback]
    }

    /// Next or previous Space on `screen`. `direction` is `+1` (next) or `-1`
    /// (previous). Returns `nil` at the ends — Space switching does not wrap.
    func adjacentSpace(for screen: NSScreen, direction: Int) -> SpaceInfo? {
        let spaces = spaces(for: screen)
        guard
            let currentID = currentSpaceID(for: screen),
            let idx = spaces.firstIndex(where: { $0.id == currentID }),
            let next = BoundedIndex.moving(idx, by: direction, count: spaces.count)
        else { return nil }
        return spaces[next]
    }

    func switchTo(_ space: SpaceInfo) {
        SpacesAPI.switchTo(space)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if SpacesAPI.currentSpaceID(for: space.displayUUID) == space.id {
                self.currentByDisplay[space.displayUUID] = space.id
            } else {
                self.refresh()
            }
        }
    }
}
