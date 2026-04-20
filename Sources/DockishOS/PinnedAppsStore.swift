import AppKit
import Combine
import DockishOSCore

struct PinnedApp: Identifiable, Codable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let path: String
}

/// Observable, persistent list of pinned apps shown between the Spaces and
/// Windows rows on every bar.
final class PinnedAppsStore: ObservableObject {
    static let shared = PinnedAppsStore()

    @Published private(set) var pins: [PinnedApp] = []
    private let storageKey = "DockishOS.pinnedApps"

    private init() {
        load()
    }

    // MARK: Queries

    func isPinned(bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return pins.contains(where: { $0.bundleID == id })
    }

    func runningApp(for pin: PinnedApp) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == pin.bundleID }
    }

    func icon(for pin: PinnedApp) -> NSImage {
        let path = resolvedBundleURL(for: pin)?.path ?? pin.path
        return NSWorkspace.shared.icon(forFile: path)
    }

    // MARK: Mutations

    func pin(window: WindowInfo) {
        guard let bid = window.bundleID, !isPinned(bundleID: bid) else { return }
        guard
            let app = NSRunningApplication(processIdentifier: window.pid),
            let url = app.bundleURL
        else { return }
        let name = app.localizedName ?? window.ownerName
        pins.append(PinnedApp(bundleID: bid, name: name, path: url.standardizedFileURL.path))
        save()
    }

    func pin(_ app: AppEntry) {
        guard let bid = app.bundleID, !isPinned(bundleID: bid) else { return }
        pins.append(PinnedApp(bundleID: bid, name: app.name, path: app.path.standardizedFileURL.path))
        save()
    }

    func unpin(bundleID: String) {
        pins.removeAll { $0.bundleID == bundleID }
        save()
    }

    /// Swap-based reorder. `delta = -1` moves left, `+1` moves right.
    func move(_ pin: PinnedApp, by delta: Int) {
        let next = StableIDReordering.moving(pins, itemID: pin.id, by: delta)
        guard next != pins else { return }
        pins = next
        save()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        pins.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Move the pin with `sourceID` to the slot currently occupied by
    /// `targetID` (used by drag-and-drop reordering).
    func move(sourceID: String, onto targetID: String) {
        let next = StableIDReordering.moving(pins, sourceID: sourceID, onto: targetID)
        guard next != pins else { return }
        pins = next
        save()
    }

    /// Pin a `.app` URL directly (used when dragging from Finder).
    func pinAppBundle(at url: URL) {
        guard url.pathExtension == "app" else { return }
        let bundle = Bundle(url: url)
        guard let bid = bundle?.bundleIdentifier, !isPinned(bundleID: bid) else { return }
        let display = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
        let plain = bundle?.infoDictionary?["CFBundleName"] as? String
        let name = display ?? plain ?? url.deletingPathExtension().lastPathComponent
        pins.append(PinnedApp(bundleID: bid, name: name, path: url.standardizedFileURL.path))
        save()
    }

    // MARK: Launch

    func launch(_ pin: PinnedApp) {
        if let running = runningApp(for: pin) {
            AppActivation.activate(running)
            return
        }
        guard let url = resolvedBundleURL(for: pin) else { return }
        refreshStoredPathIfNeeded(for: pin, resolvedURL: url)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    // MARK: Persistence

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([PinnedApp].self, from: data)
        else { return }
        let resolved = decoded.compactMap { resolvedPinnedApp(from: $0) }
        pins = resolved
        if resolved != decoded { save() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func resolvedBundleURL(for pin: PinnedApp) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pin.bundleID) {
            return url.standardizedFileURL
        }

        let fileURL = URL(fileURLWithPath: pin.path).standardizedFileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    private func resolvedPinnedApp(from pin: PinnedApp) -> PinnedApp? {
        guard let url = resolvedBundleURL(for: pin) else { return nil }
        if url.path == pin.path { return pin }
        return PinnedApp(bundleID: pin.bundleID, name: pin.name, path: url.path)
    }

    private func refreshStoredPathIfNeeded(for pin: PinnedApp, resolvedURL: URL) {
        guard let index = pins.firstIndex(of: pin) else { return }
        let resolvedPath = resolvedURL.standardizedFileURL.path
        guard pins[index].path != resolvedPath else { return }
        pins[index] = PinnedApp(
            bundleID: pin.bundleID,
            name: pin.name,
            path: resolvedPath
        )
        save()
    }
}
