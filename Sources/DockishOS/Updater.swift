import AppKit
import Sparkle

/// Sparkle-driven auto-update controller. Reads its feed URL + EdDSA
/// public key from the bundled `Info.plist`, so no extra runtime
/// configuration is needed.
final class Updater: NSObject {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    /// User-initiated check ("Check for Updates…").
    @objc func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// True when running from a real `.app` bundle with Sparkle bundled.
    /// `swift run` builds skip Sparkle entirely, so callers should test
    /// this before exposing update affordances.
    var canUpdate: Bool {
        Bundle.main.infoDictionary?["SUFeedURL"] != nil
    }
}
