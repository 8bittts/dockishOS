import DockishOSCore
import Foundation

struct AppEntry: Identifiable, Hashable, Sendable {
    /// The bundle's standardized path.
    let id: String
    let name: String
    let bundleID: String?
    let path: URL
    /// Precomputed once at scan time so per-keystroke scoring avoids
    /// repeating `lowercased()` / word-splitting for every candidate.
    let lowercasedName: String
    let lowercasedWords: [String]
}

extension Bundle {
    /// The app's name as its `Info.plist` gives it, or the bundle's file name.
    var appName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
    }
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
        let fileManager = FileManager.default
        var seen: Set<String> = []
        var entries: [AppEntry] = []

        for directory in directories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()
                let path = url.standardizedFileURL.path
                guard seen.insert(path).inserted else { continue }
                let bundle = Bundle(url: url)
                let name = bundle?.appName ?? url.deletingPathExtension().lastPathComponent
                let lowercasedName = name.lowercased()
                entries.append(AppEntry(
                    id: path,
                    name: name,
                    bundleID: bundle?.bundleIdentifier,
                    path: url,
                    lowercasedName: lowercasedName,
                    lowercasedWords: AppSearchScorer.lowercasedWords(of: lowercasedName)
                ))
            }
        }
        return entries.sorted {
            let primary = $0.name.localizedCaseInsensitiveCompare($1.name)
            if primary != .orderedSame { return primary == .orderedAscending }
            return $0.path.path.localizedCaseInsensitiveCompare($1.path.path) == .orderedAscending
        }
    }
}
