import AppKit
import Combine

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
        NSWorkspace.shared.icon(forFile: pin.path)
    }

    // MARK: Mutations

    func pin(window: WindowInfo) {
        guard let bid = window.bundleID, !isPinned(bundleID: bid) else { return }
        guard
            let app = NSRunningApplication(processIdentifier: window.pid),
            let url = app.bundleURL
        else { return }
        pins.append(PinnedApp(bundleID: bid, name: window.ownerName, path: url.path))
        save()
    }

    func pin(_ app: AppEntry) {
        guard let bid = app.bundleID, !isPinned(bundleID: bid) else { return }
        pins.append(PinnedApp(bundleID: bid, name: app.name, path: app.path.path))
        save()
    }

    func unpin(bundleID: String) {
        pins.removeAll { $0.bundleID == bundleID }
        save()
    }

    /// Swap-based reorder. `delta = -1` moves left, `+1` moves right.
    func move(_ pin: PinnedApp, by delta: Int) {
        guard let i = pins.firstIndex(where: { $0.id == pin.id }) else { return }
        let j = i + delta
        guard pins.indices.contains(j) else { return }
        pins.swapAt(i, j)
        save()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        pins.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: Launch

    func launch(_ pin: PinnedApp) {
        if let running = runningApp(for: pin) {
            running.activate(options: [])
            return
        }
        let url = URL(fileURLWithPath: pin.path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    // MARK: Persistence

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([PinnedApp].self, from: data)
        else { return }
        pins = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
