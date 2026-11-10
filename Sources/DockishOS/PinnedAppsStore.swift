import AppKit
import Combine
import DockishOSCore

struct PinnedApp: Identifiable, Codable, Hashable, Sendable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let path: String
}

/// Observable, persistent list of the apps pinned to the leading end of
/// every bar.
@MainActor
final class PinnedAppsStore: ObservableObject {
    static let shared = PinnedAppsStore()

    private static let storageKey = "DockishOS.pinnedApps"

    @Published private(set) var pins: [PinnedApp] = [] {
        didSet {
            guard pins != oldValue, let data = try? JSONEncoder().encode(pins) else { return }
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private init() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let stored = try? JSONDecoder().decode([PinnedApp].self, from: data)
        else { return }
        // Render pins immediately from their persisted paths so app launch is
        // never blocked by synchronous LaunchServices / filesystem lookups.
        pins = stored
        // Then correct moved apps and drop uninstalled ones off the main
        // thread — unless the list changed while that ran.
        Task {
            let resolved = await Task.detached(priority: .utility) {
                stored.compactMap(Self.resolved)
            }.value
            if pins == stored, resolved != stored { pins = resolved }
        }
    }

    func isPinned(bundleID: String?) -> Bool {
        pins.contains { $0.bundleID == bundleID }
    }

    // MARK: Mutations

    func pin(window: WindowInfo) {
        guard
            let bundleID = window.bundleID,
            let app = NSRunningApplication(processIdentifier: window.pid),
            let url = app.bundleURL
        else { return }
        pin(bundleID: bundleID, name: app.localizedName ?? window.ownerName, url: url)
    }

    /// Pin a `.app` URL directly (used when dragging from Finder).
    func pinAppBundle(at url: URL) {
        guard
            url.pathExtension == "app",
            let bundle = Bundle(url: url),
            let bundleID = bundle.bundleIdentifier
        else { return }
        let info = bundle.infoDictionary
        let name = info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        pin(bundleID: bundleID, name: name, url: url)
    }

    func unpin(bundleID: String) {
        pins.removeAll { $0.bundleID == bundleID }
    }

    /// Swap-based reorder. `delta = -1` moves left, `+1` moves right.
    func move(_ pin: PinnedApp, by delta: Int) {
        pins = StableIDReordering.moving(pins, itemID: pin.id, by: delta)
    }

    /// Move the pin with `sourceID` to the slot currently occupied by
    /// `targetID` (used by drag-and-drop reordering).
    func move(sourceID: String, onto targetID: String) {
        pins = StableIDReordering.moving(pins, sourceID: sourceID, onto: targetID)
    }

    // MARK: Launch

    /// Brings the pinned app forward if it is running, and launches it otherwise.
    func launch(_ pin: PinnedApp) {
        guard !AppActivation.activateRunningApp(bundleID: pin.bundleID) else { return }
        guard let resolved = Self.resolved(pin) else { return }
        // The app moved since it was pinned: remember where it is now.
        if resolved != pin, let index = pins.firstIndex(of: pin) {
            pins[index] = resolved
        }
        AppActivation.launch(at: URL(fileURLWithPath: resolved.path))
    }

    // MARK: Persistence

    private func pin(bundleID: String, name: String, url: URL) {
        guard !isPinned(bundleID: bundleID) else { return }
        pins.append(PinnedApp(bundleID: bundleID, name: name, path: url.standardizedFileURL.path))
    }

    /// The pin with its path corrected to where the app is now, or nil when
    /// the app is no longer installed. Synchronous LaunchServices and
    /// filesystem work, so `nonisolated` to run off the main thread.
    nonisolated private static func resolved(_ pin: PinnedApp) -> PinnedApp? {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pin.bundleID)
            ?? URL(fileURLWithPath: pin.path)
        let path = url.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return path == pin.path ? pin : PinnedApp(bundleID: pin.bundleID, name: pin.name, path: path)
    }
}
