import Foundation

package enum AppSearchScorer {
    /// Spotlight-ish weighted match. Higher score = better fit.
    /// nil = no match.
    package static func score(query: String, name: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let q = query.lowercased()
        let n = name.lowercased()
        if n == q { return 1000 }
        if n.hasPrefix(q) { return 500 - n.count }
        let words = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.contains(where: { $0.hasPrefix(q) }) { return 200 - n.count }
        if n.contains(q) { return 100 - n.count }

        // Subsequence fallback: each query char appears in order in name.
        var nameIndex = n.startIndex
        for character in q {
            guard let found = n[nameIndex...].firstIndex(of: character) else { return nil }
            nameIndex = n.index(after: found)
        }
        return 50 - n.count
    }
}
