import Foundation
import XCTest

/// Runs the tracked `.githooks/commit-msg` against sample messages, so the hook
/// that refuses AI attribution cannot rot or lose its executable bit unseen.
final class CommitMsgHookTests: XCTestCase {
    private static let hook = RepositorySource.root.appendingPathComponent(".githooks/commit-msg")
    private static let human = [
        "GIT_AUTHOR_NAME": "Dev", "GIT_AUTHOR_EMAIL": "dev@example.com",
        "GIT_COMMITTER_NAME": "Dev", "GIT_COMMITTER_EMAIL": "dev@example.com",
    ]

    private func run(_ message: String?, identity: [String: String] = human) throws -> (status: Int32, stderr: String) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("commit-msg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("COMMIT_EDITMSG")
        if let message { try message.write(to: file, atomically: true, encoding: .utf8) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [Self.hook.path, file.path]
        process.environment = [
            "PATH": "/usr/bin:/bin", "HOME": directory.path,
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
        ].merging(identity) { _, new in new }
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()
        try process.run()
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    func testHookIsTrackedAndExecutable() throws {
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: Self.hook.path))
        let setup = try RepositorySource.read("scripts/setup-hooks.sh")
        XCTAssertTrue(setup.contains("git config core.hooksPath .githooks"))
    }

    func testAcceptsHumanCommitsAndHumanCoAuthors() throws {
        XCTAssertEqual(try run("docs: tidy the notes\n").status, 0)
        XCTAssertEqual(try run("feat: thing\n\nCo-authored-by: Bert Smith <bert@example.com>\n").status, 0)
        XCTAssertEqual(try run("feat: thing\n\nCo-authored-by: Devin Smith <devin@example.com>\n").status, 0)
        XCTAssertEqual(try run("docs: forbid AI authors\n\nClaude and Codex trailers are refused.\n").status, 0)
    }

    func testRejectsAgentTrailersAndPhrases() throws {
        let rejected = [
            "feat: thing\n\nCo-authored-by: Claude <noreply@anthropic.com>\n",
            "feat: thing\n\nCo-authored-by: Cursor Agent <cursoragent@cursor.com>\n",
            "feat: thing\n\nSigned-off-by: Codex <codex@openai.com>\n",
            "feat: thing\n\nGenerated with Claude Code\n",
            "feat: thing\n\nAI-assisted change\n",
        ]
        for message in rejected {
            let result = try run(message)
            XCTAssertEqual(result.status, 1, message)
            XCTAssertTrue(result.stderr.contains("[FAIL] commit-msg"), message)
        }
    }

    func testRejectsAnAgentAuthorOrCommitter() throws {
        var author = Self.human
        author["GIT_AUTHOR_NAME"] = "Cursor Agent"
        author["GIT_AUTHOR_EMAIL"] = "cursoragent@cursor.com"
        XCTAssertEqual(try run("feat: thing\n", identity: author).status, 1)
        var committer = Self.human
        committer["GIT_COMMITTER_EMAIL"] = "noreply@anthropic.com"
        XCTAssertEqual(try run("feat: thing\n", identity: committer).status, 1)
    }

    func testFailsClosedWithoutAMessageOrAnIdentity() throws {
        XCTAssertEqual(try run(nil).status, 1)
        var nameless = Self.human
        nameless["GIT_AUTHOR_NAME"] = ""
        XCTAssertEqual(try run("feat: thing\n", identity: nameless).status, 1)
    }
}
