import XCTest
@testable import DockishOSCore

final class AppSearchScorerTests: XCTestCase {
    /// Scores `name` the way the launcher does: lowercased once, then split.
    private func score(_ query: String, in name: String) -> Int? {
        let lowercased = name.lowercased()
        return AppSearchScorer.score(
            query: query,
            lowercasedName: lowercased,
            lowercasedWords: AppSearchScorer.lowercasedWords(of: lowercased)
        )
    }

    func testExactMatchReturnsHighestScore() {
        XCTAssertEqual(score("Safari", in: "Safari"), 1000)
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertEqual(score("", in: "Safari"), 0)
    }

    func testPrefixMatchBeatsWordPrefixAndContains() throws {
        let prefix = try XCTUnwrap(score("saf", in: "Safari"))
        let wordPrefix = try XCTUnwrap(score("saf", in: "Open Safari"))
        let contains = try XCTUnwrap(score("far", in: "Safari"))

        XCTAssertGreaterThan(prefix, wordPrefix)
        XCTAssertGreaterThan(wordPrefix, contains)
    }

    func testWordPrefixMatchesLaterWord() {
        XCTAssertEqual(score("co", in: "Visual Studio Code"), 200 - "visual studio code".count)
    }

    func testWordsSplitOnPunctuationAndDigitsStayInWords() {
        XCTAssertEqual(AppSearchScorer.lowercasedWords(of: "1password 7 - beta"), ["1password", "7", "beta"])
    }

    func testSubsequenceFallbackMatchesOrderedCharacters() {
        XCTAssertEqual(score("sfr", in: "Safari"), 50 - "safari".count)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(score("TER", in: "Terminal"), 500 - "terminal".count)
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(score("xyz", in: "Safari"))
    }
}
