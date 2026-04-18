import AppKit
import Combine

/// Observable state for the app launcher panel.
final class LauncherStore: ObservableObject {
    static let shared = LauncherStore()

    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published private(set) var results: [AppEntry] = []

    private var allApps: [AppEntry] = []
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        refreshIndex()
        $query
            .removeDuplicates()
            .sink { [weak self] q in self?.search(q) }
            .store(in: &cancellables)
    }

    func refreshIndex() {
        allApps = AppIndex.scan()
        search(query)
    }

    func search(_ q: String) {
        if q.isEmpty {
            results = allApps
        } else {
            let scored: [(AppEntry, Int)] = allApps.compactMap { app in
                AppIndex.score(query: q, name: app.name).map { (app, $0) }
            }
            results = scored.sorted { $0.1 > $1.1 }.map(\.0)
        }
        selectedIndex = 0
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    func selectedApp() -> AppEntry? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    @discardableResult
    func activateSelected() -> Bool {
        guard let app = selectedApp() else { return false }
        activate(app)
        return true
    }

    func activate(_ app: AppEntry) {
        if
            let bundleID = app.bundleID,
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        {
            running.activate(options: [])
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: app.path, configuration: config) { _, _ in }
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }
}
