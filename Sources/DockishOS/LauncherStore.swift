import AppKit
import Combine

/// Observable state for the app launcher panel.
@MainActor
final class LauncherStore: ObservableObject {
    static let shared = LauncherStore()

    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published private(set) var results: [AppEntry] = []

    private var allApps: [AppEntry] = []
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?

    private init() {
        refreshIndex()
        $query
            .removeDuplicates()
            .sink { [weak self] q in self?.search(q) }
            .store(in: &cancellables)
    }

    func refreshIndex() {
        refreshTask?.cancel()
        refreshTask = Task {
            let scanned = await Task.detached(priority: .userInitiated) {
                AppIndex.scan()
            }.value
            guard !Task.isCancelled else { return }
            allApps = scanned
            search(query)
        }
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

    func activate(_ app: AppEntry) {
        if
            let bundleID = app.bundleID,
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        {
            AppActivation.activate(running)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: app.path, configuration: config) { _, error in
            if let error {
                Diagnostics.lifecycle.error("launch failed for \(app.path.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                NSSound.beep()
            }
        }
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }
}
