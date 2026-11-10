import Combine
import DockishOSCore
import Foundation

/// Observable state for the app launcher panel.
@MainActor
final class LauncherStore: ObservableObject {
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published private(set) var results: [AppEntry] = []

    private var allApps: [AppEntry] = []
    private var queryObserver: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    init() {
        queryObserver = $query
            .removeDuplicates()
            .sink { [weak self] query in self?.search(query) }
    }

    /// Rescans the installed apps off the main thread, then reruns the search.
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

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    var selectedApp: AppEntry? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    /// Brings the app forward if it is running, and launches it otherwise.
    func activate(_ app: AppEntry) {
        if !AppActivation.activateRunningApp(bundleID: app.bundleID) {
            AppActivation.launch(at: app.path)
        }
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }

    private func search(_ query: String) {
        if query.isEmpty {
            results = allApps
        } else {
            results = allApps
                .compactMap { app in
                    AppSearchScorer.score(
                        query: query,
                        lowercasedName: app.lowercasedName,
                        lowercasedWords: app.lowercasedWords
                    ).map { (app: app, score: $0) }
                }
                .sorted { $0.score > $1.score }
                .map(\.app)
        }
        selectedIndex = 0
    }
}
