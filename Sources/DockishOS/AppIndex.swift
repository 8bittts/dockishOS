import AppKit
import DockishOSCore

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
                let stableID = pathKey
                entries.append(AppEntry(
                    id: stableID,
                    name: name,
                    bundleID: bundle?.bundleIdentifier,
                    path: url,
                    icon: NSWorkspace.shared.icon(forFile: url.path)
                ))
            }
        }
        return entries.sorted {
            let primary = $0.name.localizedCaseInsensitiveCompare($1.name)
            if primary != .orderedSame { return primary == .orderedAscending }
            return $0.path.path.localizedCaseInsensitiveCompare($1.path.path) == .orderedAscending
        }
    }

    /// Spotlight-ish weighted match. Higher score = better fit.
    /// nil = no match.
    static func score(query: String, name: String) -> Int? {
        AppSearchScorer.score(query: query, name: name)
    }
}
