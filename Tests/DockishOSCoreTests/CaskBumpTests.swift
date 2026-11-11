import Foundation
import XCTest

/// Runs `bump_cask` from `scripts/lib/cask.sh` on a copy of the real Cask, so a
/// release cannot pin the Cask to the wrong build or skip the pin unseen.
final class CaskBumpTests: XCTestCase {
    private static let library = RepositorySource.root.appendingPathComponent("scripts/lib/cask.sh")
    private static let cask = RepositorySource.root.appendingPathComponent("Casks/dockishos.rb")
    private static let checksum = String(repeating: "ab", count: 32)

    private func bump(cask: String?, version: String, checksumLine: String?) throws -> (status: Int32, cask: String) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cask-bump-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let caskFile = directory.appendingPathComponent("cask.rb")
        let checksumFile = directory.appendingPathComponent("build.sha256")
        if let cask { try cask.write(to: caskFile, atomically: true, encoding: .utf8) }
        if let checksumLine { try checksumLine.write(to: checksumFile, atomically: true, encoding: .utf8) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c",
            "fail() { echo \"$1\" >&2; exit 1; }; step() { :; }; source \"$0\"; bump_cask \"$1\" \"$2\" \"$3\"",
            Self.library.path, caskFile.path, version, checksumFile.path,
        ]
        process.standardError = Pipe()
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        let result = (try? String(contentsOf: caskFile, encoding: .utf8)) ?? ""
        return (process.terminationStatus, result)
    }

    func testPinsTheVersionAndChecksumAndNothingElse() throws {
        let original = try String(contentsOf: Self.cask, encoding: .utf8)
        let result = try bump(cask: original, version: "9.999", checksumLine: "\(Self.checksum)  App-9.999.dmg\n")
        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.cask.contains("  version \"9.999\"\n"))
        XCTAssertTrue(result.cask.contains("  sha256 \"\(Self.checksum)\"\n"))
        let changed = zip(original.split(separator: "\n"), result.cask.split(separator: "\n")).filter { $0 != $1 }
        XCTAssertEqual(changed.count, 2)
        XCTAssertEqual(original.split(separator: "\n").count, result.cask.split(separator: "\n").count)
    }

    func testFailsClosedOnBadInput() throws {
        let original = try String(contentsOf: Self.cask, encoding: .utf8)
        let good = "\(Self.checksum)  App.dmg\n"
        XCTAssertEqual(try bump(cask: original, version: "9.999", checksumLine: "not-a-checksum  App.dmg\n").status, 1)
        XCTAssertEqual(try bump(cask: original, version: "9.999", checksumLine: nil).status, 1)
        XCTAssertEqual(try bump(cask: nil, version: "9.999", checksumLine: good).status, 1)
        XCTAssertEqual(try bump(cask: original, version: "v9.999", checksumLine: good).status, 1)
        XCTAssertEqual(try bump(cask: "cask \"x\" do\nend\n", version: "9.999", checksumLine: good).status, 1)
    }

    func testTheReleaseScriptPinsTheCaskBeforeItCommits() throws {
        let release = try RepositorySource.read("scripts/release-dockishOS.sh")
        let bump = try XCTUnwrap(release.range(of: "bump_cask \"$CASK_FILE\""))
        let commit = try XCTUnwrap(release.range(of: "git commit -m \"release:"))
        XCTAssertLessThan(bump.lowerBound, commit.lowerBound)
        XCTAssertTrue(release.contains("source \"${REPO_ROOT}/scripts/lib/cask.sh\""))
        XCTAssertTrue(release[bump.upperBound..<commit.lowerBound].contains("\"$CASK_FILE\""))
    }
}
