import Foundation

package enum AppSearchScorer {
    /// Splits an already-lowercased name into its alphanumeric words, matching
    /// the separator rule used by `score`.
    package static func lowercasedWords(of lowercasedName: String) -> [String] {
        lowercasedName.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Spotlight-ish weighted match. Higher score = better fit.
    /// nil = no match.
    package static func score(query: String, name: String) -> Int? {
        let n = name.lowercased()
        return score(query: query, lowercasedName: n, lowercasedWords: lowercasedWords(of: n))
    }

    /// Scoring entry point that reuses a precomputed lowercased name and its
    /// word split, avoiding per-keystroke `lowercased()`/`split(...)` work.
    /// Behaviour is identical to `score(query:name:)`.
    package static func score(
        query: String,
        lowercasedName n: String,
        lowercasedWords words: [String]
    ) -> Int? {
        guard !query.isEmpty else { return 0 }
        let q = query.lowercased()
        if n == q { return 1000 }
        if n.hasPrefix(q) { return 500 - n.count }
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
