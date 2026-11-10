package enum AppSearchScorer {
    /// Splits an already-lowercased name into its alphanumeric words.
    package static func lowercasedWords(of lowercasedName: String) -> [String] {
        lowercasedName.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Spotlight-ish weighted match. Higher score = better fit; nil = no match.
    ///
    /// Takes the lowercased name and its word split precomputed, so a keystroke
    /// does not repeat that work for every candidate.
    package static func score(
        query: String,
        lowercasedName name: String,
        lowercasedWords words: [String]
    ) -> Int? {
        guard !query.isEmpty else { return 0 }
        let query = query.lowercased()
        if name == query { return 1000 }
        if name.hasPrefix(query) { return 500 - name.count }
        if words.contains(where: { $0.hasPrefix(query) }) { return 200 - name.count }
        if name.contains(query) { return 100 - name.count }

        // Subsequence fallback: each query character appears in order in the name.
        var nameIndex = name.startIndex
        for character in query {
            guard let found = name[nameIndex...].firstIndex(of: character) else { return nil }
            nameIndex = name.index(after: found)
        }
        return 50 - name.count
    }
}
