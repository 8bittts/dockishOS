import Foundation

/// Reads a tracked file by its path from the repository root, for the tests
/// that pin a contract living in the app target, a script, or the bundle plist.
enum RepositorySource {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DockishOSCoreTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // repo root

    /// File names of the app target's Swift sources. Fails when there are too
    /// few, so a test that loops over them cannot pass on an empty list.
    static func appSourceNames() throws -> [String] {
        let names = try FileManager.default
            .contentsOfDirectory(atPath: root.appendingPathComponent("Sources/DockishOS").path)
            .filter { $0.hasSuffix(".swift") }
        guard names.count > 20 else { throw CocoaError(.fileNoSuchFile) }
        return names
    }

    static func read(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
