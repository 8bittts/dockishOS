import XCTest
@testable import DockishOSCore

final class AppSearchScorerTests: XCTestCase {
    func testExactMatchReturnsHighestScore() {
        XCTAssertEqual(AppSearchScorer.score(query: "Safari", name: "Safari"), 1000)
    }

    func testPrefixMatchBeatsWordPrefixAndContains() {
        let prefix = AppSearchScorer.score(query: "saf", name: "Safari")
        let wordPrefix = AppSearchScorer.score(query: "saf", name: "Open Safari")
        let contains = AppSearchScorer.score(query: "far", name: "Safari")

        XCTAssertNotNil(prefix)
        XCTAssertNotNil(wordPrefix)
        XCTAssertNotNil(contains)
        XCTAssertGreaterThan(prefix!, wordPrefix!)
        XCTAssertGreaterThan(wordPrefix!, contains!)
    }

    func testWordPrefixMatchesLaterWord() {
        XCTAssertEqual(
            AppSearchScorer.score(query: "co", name: "Visual Studio Code"),
            200 - "visual studio code".count
        )
    }

    func testSubsequenceFallbackMatchesOrderedCharacters() {
        XCTAssertEqual(
            AppSearchScorer.score(query: "sfr", name: "Safari"),
            50 - "safari".count
        )
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(
            AppSearchScorer.score(query: "TER", name: "Terminal"),
            500 - "terminal".count
        )
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(AppSearchScorer.score(query: "xyz", name: "Safari"))
    }

    func testPrecomputedPathMatchesNamePath() {
        let names = [
            "Safari", "Open Safari", "Visual Studio Code", "Terminal",
            "1Password 7", "Final Cut Pro", "System Settings", "",
        ]
        let queries = ["", "saf", "co", "sfr", "TER", "xyz", "1", "pro", "system"]
        for name in names {
            let lower = name.lowercased()
            let words = AppSearchScorer.lowercasedWords(of: lower)
            for query in queries {
                XCTAssertEqual(
                    AppSearchScorer.score(query: query, name: name),
                    AppSearchScorer.score(query: query, lowercasedName: lower, lowercasedWords: words),
                    "Mismatch for query \(query) name \(name)"
                )
            }
        }
    }
}
