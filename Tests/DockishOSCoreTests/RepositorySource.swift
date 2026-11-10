import Foundation

/// Reads a tracked file by its path from the repository root, for the tests
/// that pin a contract living in the app target, a script, or the bundle plist.
enum RepositorySource {
    static func read(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent() // DockishOSCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // repo root
        return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
