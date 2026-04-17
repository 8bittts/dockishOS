import AppKit

struct AppEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String?
    let path: URL
    let icon: NSImage
}

enum AppIndex {
    private static let directories: [URL] = [
        "/Applications",
        "/System/Applications",
        ("~/Applications" as NSString).expandingTildeInPath,
    ].map { URL(fileURLWithPath: $0) }

    /// Recursively scan the standard app directories for `.app` bundles.
    /// Skips contents inside each `.app` so we don't recurse into helpers.
    static func scan() -> [AppEntry] {
        let fm = FileManager.default
        var seen: Set<String> = []
        var entries: [AppEntry] = []

        for dir in directories where fm.fileExists(atPath: dir.path) {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()
                let pathKey = url.standardizedFileURL.path
                guard !seen.contains(pathKey) else { continue }
                seen.insert(pathKey)
                let bundle = Bundle(url: url)
                let display = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                let plain = bundle?.infoDictionary?["CFBundleName"] as? String
                let name = display ?? plain ?? url.deletingPathExtension().lastPathComponent
                entries.append(AppEntry(
                    id: bundle?.bundleIdentifier ?? pathKey,
                    name: name,
                    bundleID: bundle?.bundleIdentifier,
                    path: url,
                    icon: NSWorkspace.shared.icon(forFile: url.path)
                ))
            }
        }
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Spotlight-ish weighted match. Higher score = better fit.
    /// nil = no match.
    static func score(query: String, name: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let q = query.lowercased()
        let n = name.lowercased()
        if n == q { return 1000 }
        if n.hasPrefix(q) { return 500 - n.count }
        let words = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.contains(where: { $0.hasPrefix(q) }) { return 200 - n.count }
        if n.contains(q) { return 100 - n.count }
        // Subsequence fallback: each query char appears in order in name.
        var ni = n.startIndex
        for ch in q {
            guard let found = n[ni...].firstIndex(of: ch) else { return nil }
            ni = n.index(after: found)
        }
        return 50 - n.count
    }
}
